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
    titleTemplate: _.template "<h2><%= model %></h2>"
    searchTemplate: _.template """
        <input type="text" class="search-query input-block-level pull-right" placeholder="<%= model.detail || model %>" value="<%= data[model.query || "q"] || "" %>"></input>
    """
    paginationTemplate: _.template """
        <div class="row">
            <div class="span6">
                <div id="info">Showing <%= from %> to <%= to %><%= total %></div>
            </div>
            <div class="span6">
                <div class="pagination">
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
    dataTemplate: _.template """
        <% _.each(collection.models, function (row) { %>
            <tr>
                <% _.each(columns, function (col, name) { %>
                    <td class="<%= col.className || "" %>">
                        <%= col.draw ? col.draw(row) : row.get(name) || "" %>
                    </td>
                <% }) %>
            </tr>
        <% }) %>
        <% if (collection.models.length == 0) { %>
            <tr>
                <td colspan="10"><%= empty %></td>
            </tr>
        <% } %>
    """
    columnsTemplate: _.template """
        <% _.each(model, function (col, key) { %>
            <th abbr="<%= key || col %>"
             class="<%= !col.nosort && "sorting" %> <%= ((key || col) == data.sort_col) && "sorting_" + data.sort_dir %> <%= col.className || "" %>">
                <%= col.header || key %>
            </th>
        <% }) %>
    """
    template: _.template """
        <div class="row-fluid">
            <div class="span3">
                <%= title %>
            </div>

            <div class="filters controls pagination-centered span6">
            </div>

            <div class="span3">
                <%= search %>
            </div>
        </div>

        <table class="table table-striped table-bordered">
            <thead>
                <tr>
                    <%= columns %>
                </tr>
            </thead>
            <tbody>
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
        if @pagination
            @data.page = parseInt(@data.page) or @page or 1
            @data.size = parseInt(@data.size) or @size or 10
        return @

    # Return a parsed querystring with the "?" (eg. query = "/users?hi=1&bye=hello"
    # would return {hi: "1", bye: "hello"} )
    parseQueryString: (uri) ->
        ret = {}
        if (i = uri.indexOf("?")) >= 0
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
                    filterClass: filter.className or ""
                    options: filter.options
                    init: (filter.set or _.identity) @data[name] or filter.init or ""
                    setData: @setData
            when "button"
                return new ButtonFilter
                    id: name
                    off: filter.off or "false"
                    on: filter.on or "true"
                    filterClass: filter.className or ""
                    init: (filter.set or _.identity) @data[name] or filter.init or filter.off or "false"
                    setData: @setData
            when "input"
                return new InputFilter
                    id: name
                    filterClass: filter.className or ""
                    get: filter.get or _.identity
                    init: (filter.set or _.identity) @data[name] or filter.init or ""
                    setData: @setData
        # For custom filters, we just provide the setData function
        filter.setData = @setData
        filter.init = (filter.set or _.identity) @data[name] or filter.init or ""
        return filter

    # Update collection with search query
    updateSearch: (e) =>
        @setData @search.query or "q", e.currentTarget.value

    # Navigate to url with all the parameters in data in the querystring
    updateUrl: =>
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
            @router.navigate uri
        return @

    # Update the collection given all the options/filters
    update: =>
        @trigger "updating"
        @collection.fetch data: @data
        @updateUrl()

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
        $("tbody", @$el).html @dataTemplate
            collection: @collection
            columns:    @columns
            empty:      @empty or "No records to show"
        if @pagination
            @refreshPagination()
        @trigger "updated"
        return @

    # Go to a requested page
    toPage: (e) =>
        @setData "page", parseInt e.currentTarget.childNodes[0].text

    # Go to the previous page in the collection
    prevPage: =>
        @setData "page", @data.page - 1

    # Go to the next page in the collection
    nextPage: =>
        @setData "page", @data.page + 1

    # Toggle/Select sort column and direction, and update table accodingly
    toggleSort: (e) =>
        el = e.currentTarget
        cl = el.className
        sort_dir = ""
        if cl.indexOf("sorting_desc") >= 0
            sort_dir = "asc"
        else if cl.indexOf("sorting") >= 0
            sort_dir = "desc"
        else
            return @
        $("th", @$el).removeClass "sorting_desc sorting_asc"
        $(el, @$el).addClass "sorting_" + sort_dir
        @setData "sort_col", el.abbr, "sort_dir", sort_dir

    # Apply a template to a model and return the result (string), or empty
    # string if model is false/undefined
    applyTemplate: (template, model) ->
        (model and template data: @data, model: model) or ""

    # Render skeleton of the table, creating filters and other additions,
    # and trigger an update of the collection
    render: =>
        @$el.html @template
            empty:      @empty or ""
            title:      @applyTemplate @titleTemplate,   @title
            search:     @applyTemplate @searchTemplate,  @search
            columns:    @applyTemplate @columnsTemplate, @columns

        @filters = _.map(@filters, (filter, name) => @createFilter(name, filter))
        filtersDiv = $(".filters", @$el)
        _.each @filters, (filter) -> filtersDiv.append filter.render().el
        @update()

###
Filters
-------
###

class Filter extends Backbone.View
    tagName: "div"
    className: "inline pull-left"

    initialize: ->
        @id = @options.id
        @setData = @options.setData

    # Helper function to prettify names (eg. hi_world -> Hi World)
    prettyName: (str) ->
        str.charAt(0).toUpperCase() + str.substring(1).replace(/_(\w)/g, (match, p1) -> " " + p1.toUpperCase())

    render: =>
        @options.name = @prettyName(@id)
        @$el.html @template @options
        return @

class InputFilter extends Filter
    template: _.template """
        <span class="add-on"><%= name %></span><input type="text" class="filter <%= filterClass %>" value="<%= init %>"></input>
    """
    className: "input-prepend inline pull-left"
    events:
        "change .filter": "update"

    update: (e) =>
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
    className: "btn-group inline pull-left"
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
                    name = @prettyName option
                {name: name, value: value}

    update: (e) =>
        $(".btn", @$el).removeClass "active"
        $(e.currentTarget, @$el).addClass "active"
        @setData @id, e.currentTarget.value
