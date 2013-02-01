# = require_self
# = require ./tabs/file-tab
# = require ./tabs/url-tab
# = require ./tabs/remote-tab

uploadcare.whenReady ->
  {
    namespace,
    utils,
    files,
    jQuery: $
  } = uploadcare

  {t} = uploadcare.locale
  {tpl} = uploadcare.templates

  namespace 'uploadcare', (ns) ->

    currentDialogPr = null

    ns.isDialogOpened = -> 
      currentDialogPr != null

    ns.closeDialog = ->
      currentDialogPr?.reject()

    ns.openDialog = (settings = {}, currentFile = null) ->
      ns.closeDialog()
      settings = utils.buildSettings settings
      dialog = new Dialog(settings, currentFile)
      return currentDialogPr = dialog.publicPromise()
        .always ->
          currentDialogPr = null

    class Dialog
      constructor: (@settings, currentFile) ->
        # TODO: handle currentFile
        @dfd = $.Deferred()
        @dfd.always(=> @__closeDialog())

        @content = $(tpl('dialog'))
          .hide()
          .appendTo('body')

        @content.on 'click', (e) =>
          e.stopPropagation()
          @dfd.reject() if e.target == e.currentTarget

        closeButton = @content.find('@uploadcare-dialog-close')
        closeButton.on 'click', => @dfd.reject()

        $(window).on 'keydown', (e) =>
          @dfd.reject() if e.which == 27 # Escape

        @__prepareTabs()
        @content.fadeIn('fast')

      publicPromise: ->
        promise = @dfd.promise()
        promise.reject = @dfd.reject
        return promise

      __prepareTabs: ->
        @tabs = {}
        for tabName in @settings.tabs when tabName not of @tabs
          @tabs[tabName] = @addTab(tabName)
          throw "No such tab: #{tabName}" unless @tabs[tabName]

        @switchTab(@settings.tabs[0])

      __closeDialog: ->
        @content.fadeOut 'fast', => @content.off().remove()

      addTab: (name) ->
        {tabs} = uploadcare.widget

        tabCls = switch name
          when 'file' then tabs.FileTab
          when 'url' then tabs.UrlTab
          when 'facebook' then tabs.RemoteTabFor 'facebook'
          # when 'dropbox' then tabs.RemoteTabFor 'dropbox'
          when 'gdrive' then tabs.RemoteTabFor 'gdrive'
          when 'instagram' then tabs.RemoteTabFor 'instagram'

        return false if not tabCls

        tab = new tabCls @dfd.promise(), @settings, (fileType, data) =>
          file = ns.fileFrom @settings, fileType, data
          @dfd.resolve(file)

        if tab
          $('<li>')
            .addClass("uploadcare-dialog-tab-#{name}")
            .attr('title', t("tabs.#{name}.title"))
            .on('click', => @switchTab(name))
            .appendTo(@content.find('.uploadcare-dialog-tabs'))
          panel = $('<div>')
            .hide()
            .addClass('uploadcare-dialog-tabs-panel')
            .addClass("uploadcare-dialog-tabs-panel-#{name}")
            .appendTo(@content.find('.uploadcare-dialog-body'))
          panel.append(tpl("tab-#{name}"))
          tab.setContent(panel)
        tab

      switchTab: (@currentTab) ->
        @content.find('.uploadcare-dialog-body')
          .find('.uploadcare-dialog-selected-tab')
            .removeClass('uploadcare-dialog-selected-tab')
            .end()
          .find(".uploadcare-dialog-tab-#{@currentTab}")
            .addClass('uploadcare-dialog-selected-tab')
            .end()
          .find('> div')
            .hide()
            .filter(".uploadcare-dialog-tabs-panel-#{@currentTab}")
              .show()

        @dfd.notify @currentTab
