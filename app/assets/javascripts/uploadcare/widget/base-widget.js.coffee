# = require ../files
# = require ./dragdrop
# = require ./template
# = require ./dialog
# = require_self
# = require ./widget
# = require ./multiple-widget

{
  namespace,
  utils,
  settings: s,
  jQuery: $,
  dragdrop,
  locale: {t}
} = uploadcare

namespace 'uploadcare.widget', (ns) ->
  class ns.BaseWidget

    constructor: (element) ->
      @element = $(element)
      @settings = s.build @element.data()

      @__onUploadComplete = $.Callbacks()
      @__onChange = $.Callbacks().add (object) =>
        object?.promise().done (info) =>
          __onUploadComplete.fire info

      @__setupWidget()

      @element.on 'change.uploadcare', @reloadInfo
      @reloadInfo()

    __setupWidget: ->
      @template = new ns.Template(@settings, @element)

      @template.addButton('cancel', t('buttons.cancel')).on('click', @__reset)
      @template.addButton('remove', t('buttons.remove')).on('click', @__reset)

      # Create the dialog and widget buttons
      if @settings.tabs.length > 0
        if 'file' in @settings.tabs
          @template.addButton('file').on 'click', =>
            @openDialog('file')

        @template.addButton('dialog').on 'click', =>
          @openDialog()

      @template.content.on 'click', '@uploadcare-widget-file-name', =>
        @openDialog()

      # Enable drag and drop
      dragdrop.receiveDrop(@template.dropArea, @__handleDirectSelection)
      @template.dropArea.on 'dragstatechange.uploadcare', (e, active) =>
        unless active && uploadcare.isDialogOpened()
          @template.dropArea.toggleClass('uploadcare-dragging', active)

      @template.reset()

    __infoToValue: (info) ->
      if info.cdnUrlModifiers || @settings.pathValue
        info.cdnUrl
      else
        info.uuid

    __setValue: (value) ->
      if @element.val() != value
        @element.val(value)
        @__onChange.fire @__currentObject()

    __reset: =>
      @__clearCurrentObj()
      @template.reset()
      @__setValue ''

    __watchCurrentObject: ->
      object = @__currentFile()
      if object
        @template.listen object
        object
          .done (info) =>
            if object == @__currentFile()
              @__onUploadingDone(info)
          .fail (error) =>
            if object == @__currentFile()
              @__onUploadingFailed(error)

    __onUploadingDone: (info) ->
      @__setValue @__infoToValue(info)
      @template.setFileInfo(info)
      @template.loaded()

    __onUploadingFailed: (error) ->
      @template.error error

    reloadInfo: =>
      @value @element.val()

    api: ->
      unless @__api
        @__api = utils.bindAll this, [
          'openDialog'
          'reloadInfo'
          'value'
        ]
        @__api.onChange = utils.publicCallbacks @__onChange
        @__api.onUploadComplete = utils.publicCallbacks @__onUploadComplete
        @__api.inputElement = @element.get(0)
      @__api
