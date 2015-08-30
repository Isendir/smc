{Actions, Store, Table, flux}  = require('flux')
misc = require('misc')
{salvus_client} = require('salvus_client')

# Define account actions
class AccountActions extends Actions
    # NOTE: Can test causing this action by typing this in the Javascript console:
    #    require('flux').flux.getActions('account').setTo({first_name:'William'})
    setTo: (payload) ->
        return payload

    set_user_type: (user_type) ->
        @setTo(user_type: user_type)

    sign_in : (email, password) ->
        salvus_client.sign_in
            email_address : email
            password      : password
            remember_me   : true
            timeout       : 30
            cb            : (error, mesg) =>
                if error
                    @setTo(sign_in_error : "There was an error signing you in (#{error}).  Please try again; if that doesn't work after a few minutes, email help@sagemath.com.")
                    return
                switch mesg.event
                    when 'sign_in_failed'
                        @setTo(sign_in_error : mesg.reason)
                    when 'signed_in'
                        break
                    when 'error'
                        @setTo(sign_in_error : mesg.reason)
                    else
                        # should never ever happen
                        @setTo(sign_in_error : "The server responded with invalid message when signing in: #{JSON.stringify(mesg)}")

    set_sign_in_strategies : ->
        salvus_client.query
            query :
                passport_settings: [strategy: null]
            cb    : (err, resp) =>
                if resp?
                    strategies = (s.strategy for s in resp.query.passport_settings)
                    @setTo(strategies : strategies)


    zxcvbn : undefined

    sign_in_password_score : (password) =>
        # if the password checking library is loaded, render a password strength indicator -- otherwise, don't
        if @zxcvbn?
            if @zxcvbn != 'loading'
                # explicitly ban some words.
                @setTo(sign_in_password_score : @zxcvbn(password, ['sagemath','salvus','sage','sagemathcloud','smc','mathematica','pari']))
        else
            @zxcvbn = 'loading'
            $.getScript '/static/zxcvbn/zxcvbn.js', () ->
                @zxcvbn = window.zxcvbn
        return

# Register account actions
flux.createActions('account', AccountActions)


# Define account store
class AccountStore extends Store
    constructor: (flux) ->
        super()
        ActionIds = flux.getActionIds('account')
        @register(ActionIds.setTo, @setTo)

        # Use the database defaults for all account info until this gets set after they login
        @state = misc.deep_copy(require('schema').SCHEMA.accounts.user_query.get.fields)
        @state.user_type = if localStorage.remember_me? then 'signing_in' else 'public'  # default

    setTo: (payload) ->
        @setState(payload)

    # User type
    #   - 'public'     : user is not signed in at all, and not trying to sign in
    #   - 'signing_in' : user is currently waiting to see if sign-in attempt will succeed
    #   - 'signed_in'  : user has successfully authenticated and has an id
    get_user_type: ->
        return @state.user_type

    get_account_id: ->
        return @state.account_id

    is_logged_in : ->
        return @state.account_id?

    is_admin: ->
        if @state.groups?
            return 'admin' in @state.groups

    get_terminal_settings: ->
        return @state.terminal

    get_editor_settings: ->
        return @state.editor_settings

    get_fullname: =>
        return "#{@state.first_name ? ''} #{@state.last_name ? ''}"

    get_username: =>
        return misc.make_valid_name(@get_fullname())

    get_confirm_close: =>
        return @state.other_settings?.confirm_close

    # Total ugprades this user is paying for (sum of all upgrades from memberships)
    get_total_upgrades: =>
        require('upgrades').get_total_upgrades(@state.stripe_customer?.subscriptions?.data)

    get_page_size: =>
        return @state.other_settings?.page_size ? 50  # at least have a valid value if loading...

# Register account store
flux.createStore('account', AccountStore)

# Create and register account table, which gets automatically
# synchronized with the server.
class AccountTable extends Table
    query: ->
        return 'accounts'

    _change: (table) =>
        @flux.getActions('account').setTo(table.get_one()?.toJS?())

flux.createTable('account', AccountTable)