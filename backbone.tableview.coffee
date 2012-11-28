###
TableView
---------
###

###
A View that can be used with any backbone collection, and draws a table with it.
Optionally it supports pagination, search, and any number of filters
("inputs", "button", "option"). Eg (Users is a Backbone.Collection):

    class UserTableView extends Backbone.TableView
        title: "My Users Table"
        collection: new Users()
        columns:
            name:
                header: "My Name"
            type:
                header: "Type"
            last_login:
                header: "Last Login Time"
                draw: (model) ->
                    new Date(model.get 'time')
        pagination: true
        search:
            query: "name"
            detail: "Search by Name"
        filters:
            from:
                type: "input"
                className: "date"
                init: new Date()
                get: (val) ->
                    ... process the date val ...
            my_button:
                type: "button"
            status:
                type: "option"
                options: ["all", "valid", "invalid"]
###
class Backbone.TableView extends Backbone.View
    tagName: "div"
    titleTemplate: _.template """
        <div class="<%= classSize %>">
            <h4 class="<%= model.className || "" %>"><%= model.name || model %></h4>
        </div>
    """
    filtersTemplate: _.template """
        <div class="filters controls tableview-center <%= classSize %>">
        </div>
    """
    searchTemplate: _.template """
        <div class="<%= classSize %>">
            <input type="text" class="search-query input-block-level pull-right" placeholder="<%= model.detail || model %>" value="<%- data[model.query || "q"] || "" %>"></input>
        </div>
    """
    paginationTemplate: _.template """
        <div class="row-fluid">
            <div class="span6">
                <div class="tableview-info">Showing <%= from %> to <%= to %><%= total %></div>
            </div>
            <div class="span6">
                <div class="pagination tableview-pagination">
                    <ul>
                        <li class="pager-prev <%= prevDisabled %>"><a href="javascript:void(0)">← Previous</a></li>
                        <% _.each(pages, function (page) { %>
                            <li class="pager-page <%= page.active %>"><a href="javascript:void(0)"><%= page.number %></a></li>
                        <% }) %>
                        <li class="pager-next <%= nextDisabled %>"><a href="javascript:void(0)">Next → </a></li>
                    </ul>
                </div>
            </div>
        </div>
    """
    emptyTemplate: _.template """
        <tr>
            <td colspan="10"><%= text %></td>
        </tr>
    """
    columnsTemplate: _.template """
        <% _.each(model, function (col, key) { %>
            <th abbr="<%= key || col %>"
             class="<%= !col.nosort ? "tableview-sorting" : "" %> <%= ((key || col) == data.sort_col) ? "tableview-sorting-" + data.sort_dir : "" %> <%= col.className || "" %>">
                <%= col.header || key %>
            </th>
        <% }) %>
    """
    template: _.template """
        <div class="row-fluid">
            <%= title %>

            <%= filters %>

            <%= search %>
        </div>

        <table class="table table-striped tableview-table">
            <thead>
                <tr>
                    <%= columns %>
                </tr>
            </thead>
            <tbody class="fade">
            </tbody>
        </table>

        <div id="pagination-main">
        </div>
    """
    events:
        "change .search-query":              "updateSearch"
        "click  th":                         "toggleSort"
        "click  .pager-page:not(.active)":   "toPage"
        "click  .pager-prev:not(.disabled)": "prevPage"
        "click  .pager-next:not(.disabled)": "nextPage"

    # Binds the collection update event for rendering
    initialize: ->
        @collection.on "reset", @renderData
        for key, val of @options
            this[key] = val
        @data = _.extend {}, @initialData
        if @router
            @data = _.extend(@data, @parseQueryString Backbone.history.fragment)
        if @pagination
            @data.page = parseInt(@data.page) or @page ? 1
            @data.size = parseInt(@data.size) or @size ? 10
        return @

    # Return a parsed querystring with the "?" (eg. query = "/users?hi=1&bye=hello"
    # would return {hi: "1", bye: "hello"} )
    parseQueryString: (uri) ->
        ret = {}
        if uri and (i = uri.indexOf("?")) >= 0
            uri    = uri.substring(i + 1)
            search = /([^&=]+)=?([^&]*)/g
            decode = (s) -> decodeURIComponent(s.replace(/\+/g, " "))
            while match = search.exec(uri)
               ret[decode(match[1])] = decode(match[2])
        return ret

    # Set data and update collection
    setData: (args...) =>
        if @pagination
            @data.page = 1
        while args.length > 1
            [key, val, args...] = args
            if val? and (val == false or val == 0 or val)
                @data[key] = val
            else
                delete @data[key]
        @update()

    # Creates a filter from a filter config definition
    createFilter: (name, filter) =>
        options =
            id: name
            extraId: filter.extraId
            name: filter.name ? @prettyName name
            off: filter.off ? "false"
            on: filter.on ? "true"
            filterClass: filter.className ? ""
            options: filter.options
            init: (filter.set ? _.identity) @data[name] ? filter.init ? "", @data[filter.extraId] ? filter.extraInit ? ""
            setData: @setData
            get: filter.get ? _.identity
            getExtraId: filter.getExtraId ? _.identity
        switch filter.type
            when "option"
                return new Backbone.TableView.ButtonOptionFilter options
            when "dropdown"
                return new Backbone.TableView.DropdownFilter options
            when "input"
                return new Backbone.TableView.InputFilter options
            when "button"
                if not options.init
                    options.init = filter.off ? "false"
                return new Backbone.TableView.ButtonFilter options
            when "buttongroup"
                return new Backbone.TableView.ButtonGroupFilter options
            when "custom"
                # For custom filters, we just provide the setData function
                filter.setData = @setData
                filter.init = (filter.set ? _.identity) @data[name] ? filter.init ? ""
                return filter

    # Update collection with search query
    updateSearch: (e) =>
        @setData @search.query or "q", e.currentTarget.value

    # Navigate to url with all the parameters in data in the querystring
    updateUrl: (replace) =>
        if @router
            uri = Backbone.history.fragment
            if (i = uri.indexOf "?") >= 0
                uri = uri.substring 0, i
            param = $.param @data
            if param
                uri += "?" + param
            @router.navigate uri, replace: replace
        return @

    # Update the collection given all the options/filters
    update: (replace, skipFetch) =>
        @$("tbody").removeClass("in")
        @trigger "updating"
        @updateUrl replace
        if not skipFetch
            @collection.fetch data: @filterData?(_.clone(@data)) or @data
        else
            @renderData()
        return @

    # Refresh the pagination div at the bottom
    refreshPagination: =>
        from = (@data.page - 1) * @data.size
        to   = from + @collection.size()
        if @collection.size() > 0 then from++
        max  = if @collection.count? then _.result(@collection, "count") else -1
        if max < 0
            maxPage  = 1
            pageFrom = @data.page
            pageTo   = @data.page
            total    = ""
        else
            maxPage  = Math.ceil(max / @data.size) or 1
            pageFrom = _.max [1, @data.page - 2 - _.max [0, 2 + @data.page - maxPage]]
            pageTo   = _.min [maxPage, @data.page + 2 + _.max [0, 3 - @data.page]]
            total    = " of " + max + " entries"
        pages = ({number: i, active: (i == @data.page and "active") or ""} for i in _.range pageFrom, pageTo + 1)
        @$("#pagination-main").html @paginationTemplate
            from: from
            to: to
            total: total
            prevDisabled: if @data.page == 1 then "disabled" else ""
            nextDisabled: if to == max then "disabled" else ""
            pages: pages
        return @

    # Render the collection in the tbody section of the table
    renderData: =>
        body = @$("tbody")
        if @collection.models.length == 0
            body.html @emptyTemplate text: @empty ? "No records to show"
        else
            body.html ""
            for model in @collection.models
                row = $("<tr>")
                for name, column of @columns
                    col = $("<td>").addClass(column.className).addClass(column.tdClass)
                    if column.draw?
                        col.html column.draw model, @
                    else
                        col.text model.get(name) ? ""
                    row.append col
                row = @rowTransformer(row, model) if @rowTransformer?
                body.append row
        if @pagination
            @refreshPagination()
        @trigger "updated"
        body.addClass("in")
        return @

    # Go to a requested page
    toPage: (e) =>
        @setData "page", parseInt e.currentTarget.childNodes[0].text

    # Go to the previous page in the collection
    prevPage: =>
        if @data.page > 1
            @setData "page", @data.page - 1

    # Go to the next page in the collection
    nextPage: =>
        @setData "page", @data.page + 1

    # Toggle/Select sort column and direction, and update table accodingly
    toggleSort: (e) =>
        el = e.currentTarget
        cl = el.className
        sort_dir = ""
        if cl.indexOf("tableview-sorting-asc") >= 0
            sort_dir = "desc"
        else if cl.indexOf("tableview-sorting") >= 0
            sort_dir = "asc"
        else
            return @
        @$("th").removeClass "tableview-sorting-desc tableview-sorting-asc"
        @$(el).addClass "tableview-sorting-" + sort_dir
        @setData "sort_col", el.abbr, "sort_dir", sort_dir

    # Apply a template to a model and return the result (string), or empty
    # string if model is false/undefined
    applyTemplate: (template, model, size) ->
        if not size? then size = 12
        (model and size and template data: @data, model: model, classSize: "span" + size) or ""

    # Render skeleton of the table, creating filters and other additions,
    # and trigger an update of the collection
    render: =>
        titleSize = 3
        filtersSize = 6
        searchSize = 3
        if not @search?
            filtersSize += searchSize
            searchSize = 0
        if not @title?
            filtersSize += titleSize
            titleSize = 0
        else if not @filters?
            titleSize += filtersSize
            filtersSize = 0
        @$el.html @template
            title:   @applyTemplate @titleTemplate,   @title,   titleSize
            search:  @applyTemplate @searchTemplate,  @search,  searchSize
            filters: @applyTemplate @filtersTemplate, @filters, filtersSize
            columns: @applyTemplate @columnsTemplate, @columns

        filters = _.compact _.map @filters, (filter, name) => @createFilter(name, filter)
        filtersDiv = @$(".filters")
        for filter in filters
            filtersDiv.append filter.render().el
        @update true, @skipInitialFetch

    # Helper function to prettify names (eg. hi_world -> Hi World)
    prettyName: (str) ->
        str.charAt(0).toUpperCase() + str.substring(1).replace(/_(\w)/g, (match, p1) -> " " + p1.toUpperCase())

###
Filters
-------
###

class Backbone.TableView.Filter extends Backbone.View
    tagName: "div"
    className: "pull-left tableview-filterbox"

    initialize: ->
        @id = @options.id
        @extraId = @options.extraId
        @setData = @options.setData
        @options.options = _.map _.result(@options, "options"),
            (option) =>
                value = option
                if _.isArray value
                    value =
                        name: value[0]
                        value: value[1]
                else if not _.isObject value
                    value =
                        name: value
                        value: value
                value

    render: =>
        @$el.html @template @options
        return @

class Backbone.TableView.InputFilter extends Backbone.TableView.Filter
    template: _.template """
        <span class="add-on"><%= name %></span><input type="text" class="filter <%= filterClass %>" value="<%= init %>"></input>
    """
    className: "input-prepend pull-left tableview-filterbox"
    events:
        "change .filter": "update"

    update: (e) =>
        if @extraId
            @setData @id, @options.get(e.currentTarget.value), @extraId, @options.getExtraId(e.currentTarget.value)
        else
            @setData @id, @options.get e.currentTarget.value

class Backbone.TableView.ButtonFilter extends Backbone.TableView.Filter
    template: _.template """
        <button type="button" class="filter btn <%= init == on ? "active" : "" %> <%= filterClass %>"><%= name %></button>
    """
    events:
        "click .filter": "update"

    initialize: ->
        super
        @values = [@options.off, @options.on]
        @current = if @options.init == @options.off then 0 else 1

    update: (e) =>
        @$(e.currentTarget).toggleClass "active"
        @current = 1 - @current
        @setData @id, @values[@current]

class Backbone.TableView.ButtonGroupFilter extends Backbone.TableView.Filter
    template: _.template """
        <% _.each(options, function (el, i) { %>
            <button class="btn <%= _.contains(init, el.value) ? "active" : "" %> <%= !_.isUndefined(el.className) ? el.className : "" %>" value="<%= el.value %>"><%= el.name %></button>
        <% }) %>
    """
    className: "btn-group pull-left tableview-filterbox"
    events:
        "click .btn": "update"

    update: (e) =>
        @$(e.currentTarget).toggleClass "active"
        values = _.compact _.map @$(".btn"), (btn) =>
            if @$(btn).hasClass("active") then @$(btn).attr "value" else null
        @setData @id, @options.get values

class Backbone.TableView.ButtonOptionFilter extends Backbone.TableView.Filter
    template: _.template """
        <% _.each(options, function (el, i) { %>
            <button class="btn <%= init == el.value ? "active" : "" %>" value="<%= el.value %>"><%= el.name %></button>
        <% }) %>
    """
    className: "btn-group pull-left tableview-filterbox"
    events:
        "click .btn": "update"

    update: (e) =>
        @$(".btn").removeClass "active"
        @$(e.currentTarget).addClass "active"
        @setData @id, e.currentTarget.value

class Backbone.TableView.DropdownFilter extends Backbone.TableView.Filter
    template: _.template """
        <select class="filter <%= filterClass %>">
            <% _.each(options, function (el, i) { %>
                <option <%= init == el.value ? "selected='selected'" : "" %> value="<%= el.value %>"><%= el.name %></button>
            <% }) %>
        </select>
    """
    events:
        "change .filter": "update"

    update: (e) =>
        @setData @id, e.currentTarget.value
