#= require trix/elements/trix_toolbar_element
#= require trix/controllers/editor_controller

{browser, makeElement, triggerEvent, handleEvent, handleEventOnce, findClosestElementFromNode} = Trix

{attachmentSelector} = Trix.AttachmentView

Trix.registerElement "trix-editor", do ->
  id = 0

  # Contenteditable support helpers

  autofocus = (element) ->
    unless document.querySelector(":focus")
      if element.hasAttribute("autofocus") and document.querySelector("[autofocus]") is element
        element.focus()

  makeEditable = (element) ->
    return if element.hasAttribute("contenteditable")
    element.setAttribute("contenteditable", "")
    handleEventOnce("focus", onElement: element, withCallback: -> configureContentEditable(element))

  addAccessibilityRole = (element) ->
    return if element.hasAttribute("role")
    element.setAttribute("role", "textbox")

  configureContentEditable = (element) ->
    disableObjectResizing(element)
    setDefaultParagraphSeparator(element)

  disableObjectResizing = (element) ->
    if document.queryCommandSupported?("enableObjectResizing")
      document.execCommand("enableObjectResizing", false, false)
      handleEvent("mscontrolselect", onElement: element, preventDefault: true)

  setDefaultParagraphSeparator = (element) ->
    if document.queryCommandSupported?("DefaultParagraphSeparator")
      {tagName} = Trix.config.blockAttributes.default
      if tagName in ["div", "p"]
        document.execCommand("DefaultParagraphSeparator", false, tagName)

  # Style

  cursorTargetStyles = do ->
    if browser.forcesObjectResizing
      display: "inline"
      width: "auto"
    else
      display: "inline-block"
      width: "1px"

  defaultCSS: """
    %t {
      display: block;
    }

    %t:empty:not(:focus)::before {
      content: attr(placeholder);
      color: graytext;
      cursor: text;
    }

    %t a[contenteditable=false] {
      cursor: text;
    }

    %t img {
      max-width: 100%;
      height: auto;
    }

    %t #{attachmentSelector} figcaption textarea {
      resize: none;
    }

    %t #{attachmentSelector} figcaption textarea.trix-autoresize-clone {
      position: absolute;
      left: -9999px;
      max-height: 0px;
    }

    %t #{attachmentSelector} figcaption[data-trix-placeholder]:empty::before {
      content: attr(data-trix-placeholder);
      color: graytext;
    }

    %t [data-trix-cursor-target] {
      display: #{cursorTargetStyles.display} !important;
      width: #{cursorTargetStyles.width} !important;
      padding: 0 !important;
      margin: 0 !important;
      border: none !important;
    }

    %t [data-trix-cursor-target=left] {
      vertical-align: top !important;
      margin-left: -1px !important;
    }

    %t [data-trix-cursor-target=right] {
      vertical-align: bottom !important;
      margin-right: -1px !important;
    }
  """

  # Properties

  trixId:
    get: ->
      if @hasAttribute("trix-id")
        @getAttribute("trix-id")
      else
        @setAttribute("trix-id", ++id)
        @trixId

  labels:
    get: ->
      if @inputElement?.hasAttribute("id")
        inputId = @inputElement.getAttribute("id")

        inputLabels = @ownerDocument?.querySelectorAll("label[for=\"#{inputId}\"]")

      if @hasAttribute("id")
        trixEditorId = @getAttribute("id")

        trixEditorLabels = @ownerDocument?.querySelectorAll("label[for=\"#{trixEditorId}\"]")

      if findClosestElementFromNode(@parentElement, "label")
        ancestorLabels = [ findClosestElementFromNode(@parentElement, "label") ]

      [ inputLabels, trixEditorLabels, ancestorLabels ].find((labels) -> labels?.length) || []

  toolbarElement:
    get: ->
      if @hasAttribute("toolbar")
        @ownerDocument?.getElementById(@getAttribute("toolbar"))
      else if @parentNode
        toolbarId = "trix-toolbar-#{@trixId}"
        @setAttribute("toolbar", toolbarId)
        element = makeElement("trix-toolbar", id: toolbarId)
        @parentNode.insertBefore(element, this)
        element

  inputElement:
    get: ->
      if @hasAttribute("input")
        @ownerDocument?.getElementById(@getAttribute("input"))
      else if @parentNode
        inputId = "trix-input-#{@trixId}"
        @setAttribute("input", inputId)
        element = makeElement("input", type: "hidden", id: inputId)
        @parentNode.insertBefore(element, @nextElementSibling)
        element

  editor:
    get: ->
      @editorController?.editor

  name:
    get: ->
      @inputElement?.name

  value:
    get: ->
      @inputElement?.value
    set: (@defaultValue) ->
      @editor?.loadHTML(@defaultValue)

  # Controller delegate methods

  notify: (message, data) ->
    if @editorController
      triggerEvent("trix-#{message}", onElement: this, attributes: data)

  setInputElementValue: (value) ->
    @inputElement?.value = value

  # Element lifecycle

  initialize: ->
    makeEditable(this)
    addAccessibilityRole(this)

  connect: ->
    unless @hasAttribute("data-trix-internal")
      unless @editorController
        triggerEvent("trix-before-initialize", onElement: this)
        @editorController = new Trix.EditorController(editorElement: this, html: @defaultValue = @value)
        requestAnimationFrame => triggerEvent("trix-initialize", onElement: this)
      @editorController.registerSelectionManager()
      @registerResetListener()
      @registerLabelClickListener()
      autofocus(this)

  disconnect: ->
    @editorController?.unregisterSelectionManager()
    @unregisterResetListener()
    @unregisterLabelClickListener()

  # Form reset support

  registerResetListener: ->
    @resetListener = @resetBubbled.bind(this)
    window.addEventListener("reset", @resetListener, false)

  unregisterResetListener: ->
    window.removeEventListener("reset", @resetListener, false)

  registerLabelClickListener: ->
    @labelClickListener = @labelClickBubbled.bind(this)
    window.addEventListener("click", @labelClickListener, false)

  unregisterLabelClickListener: ->
    window.removeEventListener("click", @labelClickListener, false)

  resetBubbled: (event) ->
    if event.target is @inputElement?.form
      @reset() unless event.defaultPrevented

  labelClickBubbled: (event) ->
    if Array.from(@labels).includes(event.target)
      @focus()

  reset: ->
    @value = @defaultValue
