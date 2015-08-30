###############################################################################
#
# SageMathCloud: A collaborative web-based interface to Sage, IPython, LaTeX and the Terminal.
#
#    Copyright (C) 2015, William Stein
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

{React, flux, rtypes, rclass, FluxComponent}  = require('flux')

{Button, ButtonToolbar, Panel, Grid, Row, Col, Input, Well, Modal, ProgressBar, Alert} = require('react-bootstrap')

{ErrorDisplay, Icon, LabeledRow, Loading, NumberInput, Saving, SelectorInput, PasswordMeter} = require('r_misc')

account         = require('account')
misc            = require('misc')

{salvus_client} = require('salvus_client')

{PROJECT_UPGRADES} = require('schema')

# Define a component for working with the user's basic
# account information.

# in a grid:   Title [text input]
TextSetting = rclass
    displayName : 'Account-TextSetting'

    propTypes :
        label    : rtypes.string.isRequired
        value    : rtypes.string
        onChange : rtypes.func.isRequired
        onBlur   : rtypes.func

    getValue : ->
        @refs.input.getValue()

    render : ->
        <LabeledRow label={@props.label}>
            <Input
                ref      = 'input'
                type     = 'text'
                hasFeedback
                value    = {@props.value}
                onChange = {@props.onChange}
                onBlur   = {@props.onBlur}
            />
        </LabeledRow>

EmailAddressSetting = rclass
    displayName : 'Account-EmailAddressSetting'

    propTypes :
        email_address : rtypes.string
        account_id    : rtypes.string
        flux          : rtypes.object

    getInitialState : ->
        state      : 'view'   # view --> edit --> saving --> view or edit
        password   : ''
        email_adress : ''

    start_editing : ->
        @setState
            state    : 'edit'
            email_address : @props.email_address
            error    : ''
            password : ''

    cancel_editing : ->
        @setState
            state    : 'view'
            password : ''  # more secure...

    save_editing : ->
        @setState
            state : 'saving'
        salvus_client.change_email
            account_id        : @props.account_id
            old_email_address : @props.email_address
            new_email_address : @state.email_address
            password          : @state.password
            cb                : (err, resp) =>
                if not err and resp.error?
                    err = resp.error
                if err
                    @setState
                        state    : 'edit'
                        error    : "Error saving -- #{err}"
                else
                    @props.flux.getTable('account').set(email_address: @state.email_address)
                    @setState
                        state    : 'view'
                        error    : ''
                        password : ''
    is_submittable: ->
        return @state.password and @state.email_address != @props.email_address

    change_button : ->
        if @is_submittable()
            <Button onClick={@save_editing} bsStyle='success'>Change email address</Button>
        else
            <Button disabled bsStyle='success'>Change email address</Button>

    render_error : ->
        if @state.error
            <ErrorDisplay error={@state.error} onClose={=>@setState(error:'')} style={marginTop:'15px'} />

    render_value : ->
        switch @state.state
            when 'view'
                <div>{@props.email_address}
                     <Button className='pull-right' onClick={@start_editing}>Change email</Button>
                </div>
            when 'edit', 'saving'
                <Well>
                    Current email address
                    <pre>{@props.email_address}</pre>
                    New email address
                    <Input
                        autoFocus
                        type        = 'email_address'
                        ref         = 'email_address'
                        value       = {@state.email_address}
                        placeholder = 'user@example.com'
                        onChange    = {=>@setState(email_address : @refs.email_address.getValue())}
                    />
                    Current password
                    <form onSubmit={(e)=>e.preventDefault();if @is_submittable() then @save_editing()}>
                        <Input
                            type        = 'password'
                            ref         = 'password'
                            value       = {@state.password}
                            placeholder = 'Current password'
                            onChange    = {=>@setState(password : @refs.password.getValue())}
                        />
                    </form>
                    <ButtonToolbar>
                        {@change_button()}
                        <Button bsStyle='default' onClick={@cancel_editing}>Cancel</Button>
                    </ButtonToolbar>
                    {@render_error()}
                    {@render_saving()}
                </Well>

    render_saving : ->
        if @state.state == 'saving'
            <Saving />

    render : ->
        <LabeledRow label='Email address'>
            {@render_value()}
        </LabeledRow>

PasswordSetting = rclass
    displayName : 'Account-PasswordSetting'

    propTypes :
        email_address : rtypes.string

    getInitialState : ->
        state        : 'view'   # view --> edit --> saving --> view
        old_password : ''
        new_password : ''
        strength     : 0
        error        : ''

    change_password : ->
        @setState
            state    : 'edit'
            error    : ''
            zxcvbn   : undefined
            old_password : ''
            new_password : ''
            strength     : 0

    cancel_editing : ->
        @setState
            state    : 'view'
            old_password : ''
            new_password : ''
            zxcvbn   : undefined
            strength     : 0

    save_new_password : ->
        @setState
            state : 'saving'
        salvus_client.change_password
            email_address : @props.email_address
            old_password  : @state.old_password
            new_password  : @state.new_password
            cb            : (err, resp) =>
                if not err and resp.error
                    err = misc.to_json(resp.error)
                if err
                    @setState
                        state        : 'edit'
                        error        : "Error changing password -- #{err}"
                else
                    @setState
                        state        : 'view'
                        error        : ''
                        old_password : ''
                        new_password : ''
                        strength     : 0

    is_submittable: ->
        return @state.new_password and @state.new_password != @state.old_password and (not @state.zxcvbn? or @state.zxcvbn?.score > 0)

    change_button : ->
        if @is_submittable()
            <Button onClick={@save_new_password} bsStyle='success'>
                Change password
            </Button>
        else
            <Button disabled bsStyle='success'>Change password</Button>

    render_error : ->
        if @state.error
            <ErrorDisplay error={@state.error} onClose={=>@setState(error:'')} style={marginTop:'15px'}  />

    render_value : ->
        switch @state.state
            when 'view'
                <Button className='pull-right' onClick={@change_password}  style={marginTop: '8px'}>
                    Change password
                </Button>
            when 'edit', 'saving'
                <Well style={marginTop:'10px'}>
                    Current password
                    <Input
                        autoFocus
                        type        = 'password'
                        ref         = 'old_password'
                        value       = {@state.old_password}
                        placeholder = 'Current password'
                        onChange    = {=>@setState(old_password : @refs.old_password.getValue())}
                    />
                    New password
                    <form onSubmit={(e)=>e.preventDefault();if @is_submittable() then @save_new_password()}>
                        <Input
                            type        = 'password'
                            ref         = 'new_password'
                            value       = {@state.new_password}
                            placeholder = 'New password'
                            onChange    = {=>x=@refs.new_password.getValue(); @setState(zxcvbn:password_score(x), new_password:x)}
                        />
                    </form>
                    {<PasswordMeter result={@state.zxcvbn} /> if @state.zxcvbn?}
                    <ButtonToolbar>
                        {@change_button()}
                        <Button bsStyle='default' onClick={@cancel_editing}>Cancel</Button>
                    </ButtonToolbar>
                    {@render_error()}
                    {@render_saving()}
                </Well>

    render_saving : ->
        if @state.state == 'saving'
            <Saving />

    render : ->
        <LabeledRow label='Password'>
            {@render_value()}
        </LabeledRow>

# TODO: issue -- if edit an account setting in another browser and in the middle of editing
# a field here, this one will get overwritten on the prop update.  I think using state would
# fix that.
AccountSettings = rclass
    displayName : 'AccountSettings'

    propTypes :
        first_name    : rtypes.string
        last_name     : rtypes.string
        email_address : rtypes.string
        passports     : rtypes.string
        flux          : rtypes.object


    getInitialState: ->
        add_strategy_link      : undefined
        remote_strategy_button : undefined

    handle_change : (field) ->
        value = @refs[field].getValue()
        if field in ['first_name', 'last_name'] and not value and (not @props.first_name or not @props.last_name)
            # special case -- don't let them make their name empty -- that's just annoying (not enforced server side)
            return
        @props.flux.getActions('account').setTo("#{field}": value)

    save_change : (field) ->
        @props.flux.getTable('account').set("#{field}": @refs[field].getValue())

    render_add_strategy_link: ->
        if not @state.add_strategy_link
            return
        strategy = @state.add_strategy_link
        name = misc.capitalize(strategy)
        <Well>
            <h4><Icon name={strategy}/> {name}</h4>
            Link to your {name} account, so you can use {name} to
            login to your SageMathCloud account.
            <br /> <br />
            <ButtonToolbar style={textAlign: 'center'}>
                <Button href={"/auth/#{@state.add_strategy_link}"} target="_blank"
                    onClick={=>@setState(add_strategy_link:undefined)}>
                    <Icon name="external-link" /> Link my {name} account
                </Button>
                <Button onClick={=>@setState(add_strategy_link:undefined)} >
                    Cancel
                </Button>
            </ButtonToolbar>
        </Well>

    remove_strategy_click: ->
        strategy = @state.remove_strategy_button
        @setState(remove_strategy_button:undefined, add_strategy_link:undefined)
        for k, _ of @props.passports
            if misc.startswith(k, strategy)
                id = k.split('-')[1]
                break
        if not id
            return
        salvus_client.unlink_passport
            strategy : strategy
            id       : id
            cb       : (err) ->
                if err
                    ugly_error(err)

    render_remove_strategy_button: ->
        if not @state.remove_strategy_button
            return
        strategy = @state.remove_strategy_button
        name = misc.capitalize(strategy)
        if misc.len(@props.passports) <= 1 and not @props.email_address
            <Well>
                You must set an email address above or add another login method before
                you can disable login to your SageMathCloud account using your {name} account.
                Otherwise you would completely lose access to your account!
            </Well>
        else
            <Well>
                <h4><Icon name={strategy}/> {name}</h4>
                Your SageMathCloud account is linked to your {name} account, so you can
                login using it.
                <br /> <br />
                If you delink your {name} account, you will no longer be able to
                use your account to log into SageMathCloud.
                <br /> <br />
                <ButtonToolbar style={textAlign: 'center'}>
                    <Button bsStyle='danger' onClick={@remove_strategy_click} >
                        <Icon name="unlink" /> Delink my {name} account
                    </Button>
                    <Button onClick={=>@setState(remove_strategy_button:undefined)} >
                        Cancel
                    </Button>
                </ButtonToolbar>
            </Well>

    render_strategy : (strategy, strategies) ->
        if strategy != 'email'
            <Button
                onClick = {=>@setState(if strategy in strategies then {remove_strategy_button:strategy, add_strategy_link:undefined} else {add_strategy_link:strategy, remove_strategy_button:undefined})}
                key     = {strategy}
                bsStyle = {if strategy in strategies then 'info' else 'default'}>
                <Icon name={strategy} /> {misc.capitalize(strategy)}...
            </Button>

    render_sign_in_strategies : ->
        if not STRATEGIES? or STRATEGIES.length <= 1 or not @props.passports?
            return
        strategies = (x.slice(0,x.indexOf('-')) for x in misc.keys(@props.passports))
        <div>
            <hr key='hr0' />
            <h5 style={color:"#666"}>Linked accounts (only used for sign in)</h5>
            <ButtonToolbar style={marginBottom:'10px'} >
                {(@render_strategy(strategy, strategies) for strategy in STRATEGIES)}
            </ButtonToolbar>
            {@render_add_strategy_link()}
            {@render_remove_strategy_button()}
        </div>

    render : ->
        <Panel header={<h2> <Icon name='user' /> Account settings</h2>}>
            <TextSetting
                label    = 'First name'
                value    = {@props.first_name}
                ref      = 'first_name'
                onChange = {=>@handle_change('first_name')}
                onBlur   = {=>@save_change('first_name')}
                />
            <TextSetting
                label    = 'Last name'
                value    = {@props.last_name}
                ref      = 'last_name'
                onChange = {=>@handle_change('last_name')}
                onBlur   = {=>@save_change('last_name')}
                />
            <EmailAddressSetting
                email_address = {@props.email_address}
                account_id = {@props.account_id}
                flux       = {@props.flux}
                ref        = 'email_address'
                />
            <PasswordSetting
                email_address = {@props.email_address}
                ref   = 'password'
                />
            {render_sign_out_buttons()}
            {@render_sign_in_strategies()}
        </Panel>

###
# Terminal
###

# Plan: have this exact same control be available directly when using a terminal (?)
# Here Terminal = term.js global object
TERMINAL_COLOR_SCHEMES = {}
for theme, val of Terminal.color_schemes
    TERMINAL_COLOR_SCHEMES[theme] = val.comment

TERMINAL_FONT_FAMILIES =
    'droid-sans-mono': 'Droid Sans Mono'
    'Courier New'    : 'Courier New'
    'monospace'      : 'Monospace'

# TODO: in console.coffee there is also code to set the font size,
# which our store ignores...
TerminalSettings = rclass
    displayName : 'Account-TerminalSettings'

    handleChange: (obj) ->
        @props.flux.getTable('account').set(terminal: obj)

    render : ->
        if not @props.terminal?
            return <Loading />
        <Panel header={<h2> <Icon name='terminal' /> Terminal <span className='lighten'>(settings applied to newly opened terminals)</span></h2>}>
            <LabeledRow label='Terminal font size (px)'>
                <NumberInput
                    on_change = {(font_size)=>@handleChange(font_size:font_size)}
                    min       = 3
                    max       = 80
                    number    = {@props.terminal.font_size} />
            </LabeledRow>
            <LabeledRow label='Terminal font family'>
                <SelectorInput
                    selected  = {@props.terminal.font}
                    options   = {TERMINAL_FONT_FAMILIES}
                    on_change = {(font)=>@handleChange(font:font)}
                />
            </LabeledRow>
            <LabeledRow label='Terminal color scheme'>
                <SelectorInput
                    selected  = {@props.terminal.color_scheme}
                    options   = {TERMINAL_COLOR_SCHEMES}
                    on_change = {(color_scheme)=>@handleChange(color_scheme : color_scheme)}
                />
            </LabeledRow>
        </Panel>

EDITOR_SETTINGS_CHECKBOXES =
    line_wrapping             : 'scroll or wrap long lines'
    line_numbers              : 'show line numbers'
    code_folding              : 'fold code using control+Q'
    smart_indent              : 'context sensitive indentation'
    electric_chars            : 'sometimes reindent current line'
    match_brackets            : 'highlight matching brackets near cursor'
    auto_close_brackets       : 'automatically close brackets'
    match_xml_tags            : 'automatically match XML tags'
    auto_close_xml_tags       : 'automatically close XML tags'
    strip_trailing_whitespace : 'remove whenever file is saved'
    show_trailing_whitespace  : 'show spaces at ends of lines'
    spaces_instead_of_tabs    : 'send 4 spaces when the tab key is pressed'
    track_revisions           : 'record history of changes when editing files'
    extra_button_bar          : 'more editing functions (mainly in Sage worksheets)'

EditorSettingsCheckboxes = rclass
    displayName : 'Account-EditorSettingsCheckboxes'

    propTypes :
        editor_settings : rtypes.object.isRequired
        on_change       : rtypes.func.isRequired

    label_checkbox : (name, desc) ->
        return misc.capitalize(name.replace(/_/g,' ').replace(/-/g,' ').replace('xml','XML')) + ': ' + desc

    render_checkbox : (name, desc) ->
        <Input checked  = {@props.editor_settings[name]}
               key      = {name}
               type     = 'checkbox'
               label    = {@label_checkbox(name, desc)}
               ref      = {name}
               onChange = {=>@props.on_change(name, @refs[name].getChecked())}
        />

    render : ->
        <span>
            {(@render_checkbox(name, desc) for name, desc of EDITOR_SETTINGS_CHECKBOXES)}
        </span>

EditorSettingsAutosaveInterval = rclass
    displayName : 'Account-EditorSettingsAutosaveInterval'

    propTypes :
        autosave  : rtypes.number.isRequired
        on_change : rtypes.func.isRequired

    render : ->
        <LabeledRow label='Autosave interval (seconds)'>
            <NumberInput
                on_change = {(n)=>@props.on_change('autosave',n)}
                min       = 15
                max       = 900
                number    = {@props.autosave} />
        </LabeledRow>

EDITOR_COLOR_SCHEMES =
    'default'                 : 'Default'
    '3024-day'                : '3024 day'
    '3024-night'              : '3024 night'
    'ambiance-mobile'         : 'Ambiance mobile'
    'ambiance'                : 'Ambiance'
    'base16-dark'             : 'Base 16 dark'
    'base16-light'            : 'Base 16 light'
    'blackboard'              : 'Blackboard'
    'cobalt'                  : 'Cobalt'
    'eclipse'                 : 'Eclipse'
    'elegant'                 : 'Elegant'
    'erlang-dark'             : 'Erlang dark'
    'lesser-dark'             : 'Lesser dark'
    'the-matrix'              : 'The Matrix'
    'midnight'                : 'Midnight'
    'monokai'                 : 'Monokai'
    'neat'                    : 'Neat'
    'night'                   : 'Night'
    'paraiso-dark'            : 'Paraiso dark'
    'paraiso-light'           : 'Paraiso light'
    'pastel-on-dark'          : 'Pastel on dark'
    'rubyblue'                : 'Rubyblue'
    'solarized dark'          : 'Solarized dark'
    'solarized light'         : 'Solarized light'
    'tomorrow-night-eighties' : 'Tomorrow Night - Eighties'
    'twilight'                : 'Twilight'
    'vibrant-ink'             : 'Vibrant ink'
    'xq-dark'                 : 'Xq dark'
    'xq-light'                : 'Xq light'

EditorSettingsColorScheme = rclass
    displayName : 'Account-EditorSettingsColorScheme'

    propTypes :
        theme     : rtypes.string.isRequired
        on_change : rtypes.func.isRequired

    render : ->
        <LabeledRow label='Editor color scheme'>
            <SelectorInput
                options   = {EDITOR_COLOR_SCHEMES}
                selected  = {@props.theme}
                on_change = {@props.on_change}
            />
        </LabeledRow>

EDITOR_BINDINGS =
    standard : 'Standard'
    sublime  : 'Sublime'
    vim      : 'Vim'
    emacs    : 'Emacs'

EditorSettingsKeyboardBindings = rclass
    displayName : 'Account-EditorSettingsKeyboardBindings'

    propTypes :
        bindings  : rtypes.string.isRequired
        on_change : rtypes.func.isRequired

    render : ->
        <LabeledRow label='Editor keyboard bindings'>
            <SelectorInput
                options   = {EDITOR_BINDINGS}
                selected  = {@props.bindings}
                on_change = {@props.on_change}
            />
        </LabeledRow>

EditorSettings = rclass
    displayName : 'Account-EditorSettings'

    on_change : (name, val) ->
        if name == 'autosave'
            @props.flux.getTable('account').set(autosave : val)
        else
            @props.flux.getTable('account').set(editor_settings:{"#{name}":val})

    render : ->
        if not @props.editor_settings?
            return <Loading />
        <Panel header={<h2> <Icon name='edit' /> Editor (settings apply to newly (re-)opened files)</h2>}>
            <EditorSettingsAutosaveInterval
                on_change={@on_change} autosave={@props.autosave} />
            <EditorSettingsColorScheme
                on_change={(value)=>@on_change('theme',value)} theme={@props.editor_settings.theme} />
            <EditorSettingsKeyboardBindings
                on_change={(value)=>@on_change('bindings',value)} bindings={@props.editor_settings.bindings} />
            <EditorSettingsCheckboxes
                on_change={@on_change} editor_settings={@props.editor_settings} />
        </Panel>

KEYBOARD_SHORTCUTS =
    'Next file tab'                : 'control+]'
    'Previous file tab'            : 'control+['
    'Smaller text'                 : 'control+<'
    'Bigger text'                  : 'control+>'
    'Go to line'                   : 'control+L'
    'Find'                         : 'control+F'
    'Find next'                    : 'control+G'
    'Fold/unfold selected code'    : 'control+Q'
    'Shift selected text right'    : 'tab'
    'Shift selected text left'     : 'shift+tab'
    'Split view in any editor'     : 'control+I'
    'Autoindent selection'         : 'control+'
    'Multiple cursors'             : 'control+click'
    'Simple autocomplete'          : 'control+space'
    'Sage autocomplete'            : 'tab'
    'Split cell in Sage worksheet' : 'control+;'

EVALUATE_KEYS =
    'Shift-Enter' : 'shift+enter'
    'Enter'       : 'enter (shift+enter for newline)'

KeyboardSettings = rclass
    displayName : 'Account-KeyboardSettings'

    render_keyboard_shortcuts : ->
        for desc, shortcut of KEYBOARD_SHORTCUTS
            <LabeledRow key={desc} label={desc}>
                {shortcut}
            </LabeledRow>

    eval_change : (value) ->
        @props.flux.getTable('account').set(evaluate_key : value)

    render_eval_shortcut : ->
        if not @props.evaluate_key?
            return <Loading />
        <LabeledRow label='Sage Worksheet evaluate key'>
            <SelectorInput
                options   = {EVALUATE_KEYS}
                selected  = {@props.evaluate_key}
                on_change = {@eval_change}
            />
        </LabeledRow>

    render : ->
        <Panel header={<h2> <Icon name='keyboard-o' /> Keyboard shortcuts</h2>}>
            {@render_keyboard_shortcuts()}
            {@render_eval_shortcut()}
        </Panel>

OtherSettings = rclass
    displayName : 'Account-OtherSettings'

    propTypes :
        other_settings : rtypes.object
        flux           : rtypes.object
        autosave       : rtypes.number

    on_change : (name, value) ->
        @props.flux.getTable('account').set(other_settings:{"#{name}":value})

    render_confirm : ->
        if not require('feature').IS_MOBILE
            <Input
                type     = 'checkbox'
                checked  = {@props.other_settings.confirm_close}
                ref      = 'confirm_close'
                onChange = {=>@on_change('confirm_close', @refs.confirm_close.getChecked())}
                label    = 'Confirm: always ask for confirmation before closing the browser window'
            />

    render_page_size_warning : ->
        BIG_PAGE_SIZE = 500
        if @props.other_settings.page_size > BIG_PAGE_SIZE
            <Alert bsStyle='warning'>
                Your file listing page size is set to {@props.other_settings.page_size}. Sizes above {BIG_PAGE_SIZE} may cause the file listing to render slowly for directories with lots of files.
            </Alert>

    render : ->
        if not @props.other_settings
            return <Loading />
        <Panel header={<h2> <Icon name='gear' /> Other settings</h2>}>
            {@render_confirm()}
            <Input
                type     = 'checkbox'
                checked  = {@props.other_settings.mask_files}
                ref      = 'mask_files'
                onChange = {=>@on_change('mask_files', @refs.mask_files.getChecked())}
                label    = 'Mask files: grey-out files in the files viewer that you probably do not want to open'
            />
            <LabeledRow label='Default file sort'>
                <SelectorInput
                    selected  = {@props.other_settings.default_file_sort}
                    options   = {time:'Sort by time', name:'Sort by name'}
                    on_change = {(value)=>@on_change('default_file_sort', value)}
                />
            </LabeledRow>
            <LabeledRow label='File listing page size'>
            <NumberInput
                    on_change = {(n)=>@on_change('page_size',n)}
                    min       = 1
                    max       = 1000000
                    number    = {@props.other_settings.page_size} />
            </LabeledRow>
            {@render_page_size_warning()}
        </Panel>

AccountCreationToken = rclass
    displayName : 'AccountCreationToken'

    getInitialState : ->
        state : 'view'   # view --> edit --> save --> view
        token : ''
        error : ''

    edit : ->
        @setState(state:'edit')

    save : ->
        @setState(state:'save')
        token = @state.token
        salvus_client.query
            query :
                server_settings : {name:'account_creation_token',value:token}
            cb : (err) =>
                if err
                    @setState(state:'edit', error:err)
                else
                    @setState(state:'view', error:'', token:'')

    render_save_button : ->
        <Button style={marginRight:'1ex'} onClick={@save} bsStyle='success'>Save token</Button>

    render_control : ->
        switch @state.state
            when 'view'
                <Button onClick={@edit} bsStyle='warning'>Change token...</Button>
            when 'load'
                <Loading />
            when 'edit', 'save'
                <Well>
                    <form onSubmit={@save}>
                        <Input
                            ref      = 'input'
                            type     = 'text'
                            value    = {@state.token}
                            onChange = {=>@setState(token:@refs.input.getValue())}}
                        />
                    </form>
                    {@render_save_button()}
                    <Button onClick={=>@setState(state:'view', token:'')}>Cancel</Button>
                    <br /><br />
                    (Set to empty to not require a token.)
                </Well>

    render_error : ->
        if @state.error
            <ErrorDisplay error={@state.error} onClose={=>@setState(error:'')} />

    render_save : ->
        if @state.state == 'save'
            <Saving />

    render : ->
        <div>
             {@render_control()}
             {@render_save()}
             {@render_error()}
        </div>


StripeKeys = rclass
    displayName : 'Account-StripeKeys'

    getInitialState : ->
        state           : 'view'   # view --> edit --> save --> view
        secret_key      : undefined
        publishable_key : undefined
        error           : undefined

    edit : ->
        @setState(state:'edit')

    save : ->
        @setState(state:'save')
        f = (name, cb) =>
        query = (server_settings : {name:"stripe_#{name}_key", value:@state["#{name}_key"]} for name in ['secret', 'publishable'])
        salvus_client.query
            query : query
            cb    : (err) =>
                if err
                    @setState(state:'edit', error:err)
                else
                    @setState(state:'view', error:'', secret_key:'', publishable_key:'')

    cancel : ->
        @setState(state:'view', error:'', secret_key:'', publishable_key:'')

    render : ->
        <div>
            {@render_main()}
            {@render_error()}
        </div>

    render_main :->
        switch @state.state
            when 'view'
                <Button bsStyle='warning' onClick={@edit}>Change stripe keys...</Button>
            when 'load'
                <div>Loading stripe keys...</div>
            when 'save'
                <div>Saving stripe keys...</div>
            when 'edit'
                <Well>
                    <LabeledRow label='Secret key'>
                        <Input ref='input_secret_key' type='text' value={@state.secret_key}
                            onChange={=>@setState(secret_key:@refs.input_secret_key.getValue())} />
                    </LabeledRow>
                    <LabeledRow label='Publishable key'>
                        <Input ref='input_publishable_key' type='text' value={@state.publishable_key}
                            onChange={=>@setState(publishable_key:@refs.input_publishable_key.getValue())} />
                    </LabeledRow>
                    <ButtonToolbar>
                        <Button bsStyle='success' onClick={@save}>Save stripe keys...</Button>
                        <Button onClick={@cancel}>Cancel</Button>
                    </ButtonToolbar>
                </Well>

    render_error : ->
        if @state.error
            <ErrorDisplay error={@state.error} onClose={=>@setState(error:'')} />

AdminSettings = rclass
    render : ->
        if not @props.groups? or 'admin' not in @props.groups
            return <span />
        <Panel header={<h2> <Icon name='users' /> Administrative server settings</h2>}>
            <LabeledRow label='Account Creation Token'>
                <AccountCreationToken />
            </LabeledRow>
            <LabeledRow label='Stripe API Keys' style={marginTop:'15px'}>
                <StripeKeys />
            </LabeledRow>
        </Panel>


render_sign_out_buttons = ->
    <Row style={marginTop: '1ex'}>
        <Col xs=12>
            <ButtonToolbar className='pull-right'>
                <Button bsStyle='warning' onClick={account.sign_out_confirm}>
                    <Icon name='sign-out'/> Sign out
                </Button>
                <Button bsStyle='warning' onClick={account.sign_out_everywhere_confirm}>
                    <Icon name='sign-out'/> Sign out everywhere
                </Button>
            </ButtonToolbar>
        </Col>
    </Row>

# Render the entire settings component
render = () ->
    <div style={marginTop:'1em'}>
        <Row>
            <Col xs=12 md=6>
                <FluxComponent flux={flux} connectToStores={'account'} >
                    <AccountSettings />
                    <TerminalSettings />
                    <KeyboardSettings />
                </FluxComponent>
            </Col>
            <Col xs=12 md=6>
                <FluxComponent flux={flux} connectToStores={'account'} >
                    <EditorSettings />
                    <OtherSettings />
                    <AdminSettings />
                </FluxComponent>
            </Col>
        </Row>
    </div>

ugly_error = (err) ->
    if typeof(err) != 'string'
        err = misc.to_json(err)
    require('alerts').alert_message(type:"error", message:"Settings error -- #{err}")



# returns password score if password checker library
# loaded; otherwise returns undefined and starts load
zxcvbn = undefined
password_score = (password) ->
    # if the password checking library is loaded, render a password strength indicator -- otherwise, don't
    if zxcvbn?
        if zxcvbn != 'loading'
            # explicitly ban some words.
            return zxcvbn(password, ['sagemath','salvus','sage','sagemathcloud','smc','mathematica','pari'])
    else
        zxcvbn = 'loading'
        $.getScript '/static/zxcvbn/zxcvbn.js', () =>
            zxcvbn = window.zxcvbn
    return


###
Top Navbar button label at the top
###

AccountName = rclass
    displayName : 'AccountName'

    propTypes :
        first_name : rtypes.string
        last_name  : rtypes.string

    shouldComponentUpdate: (next) ->
        return @props.first_name != next.first_name or @props.last_name != next.last_name

    render : ->
        name = ''
        if @props.first_name? and @props.last_name?
            name = misc.trunc_middle(@props.first_name + ' ' + @props.last_name, 32)
        if not name.trim()
            name = "Account"
        <span><Icon name='cog' style={fontSize:'20px'}/> {name}</span>

render_top_navbar_button = ->
    <FluxComponent flux={flux} connectToStores={'account'} >
        <AccountName />
    </FluxComponent>

React.render render_top_navbar_button(), require('top_navbar').top_navbar.pages['account'].button.find('.button-label')[0]

is_mounted = false
mount = ->
    #console.log("mount account settings")
    React.render render(), document.getElementById('smc-account-settings')
    is_mounted = true

unmount = ->
    #console.log("unmount account settings")
    if is_mounted
        React.unmountComponentAtNode(document.getElementById("smc-account-settings"))
        is_mounted = false

{top_navbar} = require('top_navbar')

# This is not efficient in that we're mounting/unmounting all three pages, when only one needs to be mounted.
# When we replace the whole page by a single react component this problem will go away.
top_navbar.on "switch_to_page-account", () ->
    require("billing").render_billing($(".smc-react-billing")[0], flux)
    require("r_upgrades").render_upgrades(flux)
    mount()

top_navbar.on "switch_from_page-account", () ->
    require("billing").unmount($(".smc-react-billing")[0])
    require("r_upgrades").unmount()
    unmount()


