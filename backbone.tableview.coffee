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
            description:
                header: "Description"
                nosort: true
                draw: (model) ->
                    some_weird_formatting_function(model.get('some_text'))
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
            my_btn:
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
        <div class="filters controls pagination-centered <%= classSize %>">
        </div>
    """
    searchTemplate: _.template """
        <div class="<%= classSize %>">
            <input type="text" class="search-query input-block-level pull-right" placeholder="<%= model.detail || model %>" value="<%= data[model.query || "q"] || "" %>"></input>
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
                <tr>
                    <td colspan="10"><%= empty %></td>
                </tr>
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
            if not this[key]? then this[key] = val
        @data = $.extend({}, @initialData, @parseQueryString Backbone.history.fragment)
        @data.page = parseInt(@data.page) or @page or 1
        @data.size = parseInt(@data.size) or @size or 10
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
        switch filter.type
            when "option"
                return new ButtonOptionFilter
                    id: name
                    name: filter.name or @prettyName name
                    filterClass: filter.className or ""
                    options: filter.options
                    init: (filter.set or _.identity) @data[name] or filter.init or ""
                    setData: @setData
            when "button"
                return new ButtonFilter
                    id: name
                    name: filter.name or @prettyName name
                    off: @firstOf filter.off, "false"
                    on: @firstOf filter.on, "true"
                    filterClass: filter.className or ""
                    init: (filter.set or _.identity) (@firstOf @data[name], filter.init, filter.off, "false")
                    setData: @setData
            when "input"
                return new InputFilter
                    id: name
                    name: filter.name or @prettyName name
                    extraId: filter.extraId
                    filterClass: filter.className or ""
                    get: filter.get or _.identity
                    getExtraId: filter.getExtraId or _.identity
                    init: (filter.set or _.identity) @data[name] or filter.init or "", @data[filter.extraId] or filter.extraInit or ""
                    setData: @setData
        # For custom filters, we just provide the setData function
        filter.setData = @setData
        filter.init = (filter.set or _.identity) @data[name] or filter.init or ""
        return filter

    # Update collection with search query
    updateSearch: (e) =>
        @setData @search.query or "q", e.currentTarget.value

    # Navigate to url with all the parameters in data in the querystring
    updateUrl: (replace) =>
        if @router
            uri = Backbone.history.fragment
            if (i = uri.indexOf "?") > 0
                uri = uri.substring(0, i)
            first = true
            for key, val of @data
                if first
                    first = false
                    separator = "?"
                else
                    separator = "&"
                uri = uri + separator + key + "=" + val
            @router.navigate uri, {replace: replace}
        return @

    # Update the collection given all the options/filters
    update: (replace) =>
        $("tbody", @$el).removeClass("in")
        @trigger "updating"
        @collection.fetch data: @data
        @updateUrl replace

    # Refresh the pagination div at the bottom
    refreshPagination: =>
        from = (@data.page - 1) * @data.size
        to   = from + @collection.size()
        if @collection.size() > 0 then from++
        max  = if @collection.count? then @collection.count() else -1
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
        $("#pagination-main", @$el).html @paginationTemplate
            from: from
            to: to
            total: total
            prevDisabled: if @data.page == 1 then "disabled" else ""
            nextDisabled: if to == max then "disabled" else ""
            pages: pages
        return @

    # Render the collection in the tbody section of the table
    renderData: =>
        body = $("tbody", @$el)
        if @collection.models.length == 0
            body.html @emptyTemplate text: @empty or "No records to show"
        else
            body.html ""
            for model in @collection.models
                row = $("<tr>")
                for name, column of @columns
                    col = $("<td>").addClass(column.className).addClass(column.tdClass)
                    if column.draw?
                        col.html column.draw(model, @update, @)
                    else
                        col.html model.get(name) or ""
                    row.append col
                body.append row
        if @pagination
            @refreshPagination()
        @trigger "updated"
        $("tbody", @$el).addClass("in")
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
        $("th", @$el).removeClass "tableview-sorting-desc tableview-sorting-asc"
        $(el, @$el).addClass "tableview-sorting-" + sort_dir
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
            empty:   @empty or ""
            title:   @applyTemplate @titleTemplate,   @title,   titleSize
            search:  @applyTemplate @searchTemplate,  @search,  searchSize
            filters: @applyTemplate @filtersTemplate, @filters, filtersSize
            columns: @applyTemplate @columnsTemplate, @columns

        filters = _.map(@filters, (filter, name) => @createFilter(name, filter))
        filtersDiv = $(".filters", @$el)
        _.each filters, (filter) -> filtersDiv.append filter.render().el
        @update true

    # Helper function to prettify names (eg. hi_world -> Hi World)
    prettyName: (str) ->
        str.charAt(0).toUpperCase() + str.substring(1).replace(/_(\w)/g, (match, p1) -> " " + p1.toUpperCase())

    # Helper function that returns the first non-null argument
    firstOf: (args...) =>
        for index, arg of args
            if arg? then return arg
        return null

###
Filters
-------
###

class Filter extends Backbone.View
    tagName: "div"
    className: "pull-left tableview-filterbox"

    initialize: ->
        @id = @options.id
        @extraId = @options.extraId
        @setData = @options.setData

    render: =>
        @$el.html @template @options
        return @

class InputFilter extends Filter
    template: _.template """
        <span class="add-on"><%= name %></span><input type="text" class="filter <%= filterClass %>" value="<%= init %>"></input>
    """
    className: "input-prepend pull-left filterbox"
    events:
        "change .filter": "update"

    update: (e) =>
        if @extraId
            @setData @id, @options.get(e.currentTarget.value), @extraId, @options.getExtraId(e.currentTarget.value)
        else
            @setData @id, @options.get e.currentTarget.value

class ButtonFilter extends Filter
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
        $(e.currentTarget, @$el).toggleClass "active"
        @current = 1 - @current
        @setData @id, @values[@current]

class ButtonOptionFilter extends Filter
    template: _.template """
        <% _.each(options, function (el, i) { %>
            <button class="btn <%= init == el.value ? "active" : "" %>" value="<%= el.value %>"><%= el.name %></button>
        <% }) %>
    """
    className: "btn-group pull-left filterbox"
    events:
        "click .btn": "update"

    initialize: ->
        super
        @options.options = _.map @options.options,
            (option) =>
                value = option
                if _.isArray value
                    name = value[0]
                    value = value[1]
                else if _.isObject value
                    name = option.name
                    value = option.value
                else
                    name = option
                {name: name, value: value}

    update: (e) =>
        $(".btn", @$el).removeClass "active"
        $(e.currentTarget, @$el).addClass "active"
        @setData @id, e.currentTarget.value
