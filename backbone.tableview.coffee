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
        <input type="text" class="search-query pull-right" placeholder="<%= model.detail || model %>"></input>
    """
    paginationTemplate: _.template """
        <ul class="pager">
            <li class="pager-prev">
                <a href="javascript:void(0)">&larr; Prev</a>
            </li>
            <span class="badge badge-info page">1</span>
            <li class="pager-next">
                <a href="javascript:void(0)">Next &rarr;</a>
            </li>
        </ul>
    """
    dataTemplate: _.template """
        <% _.each(collection.models, function (row) { %>
            <tr>
                <% _.each(columns, function (col, name) { %>
                    <td class="<%= col.className || "" %>">
                        <%= col.draw ? col.draw(row) : row.get(name) %>
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
    template: _.template """
        <div class="row-fluid">
            <div class="span2">
                <%= title %>
            </div>

            <div class="filters controls pagination-centered span8">
            </div>

            <div class="span2">
                <%= search %>
            </div>
        </div>

        <table class="table table-striped table-bordered">
            <thead>
                <tr>
                    <% _.each(columns, function (col, key) { %>
                        <th abbr="<%= key || col %>" class="<%= !col.nosort && "sorting" %> <%= col.className || "" %>">
                            <%= col.header || col %>
                        </th>
                    <% }) %>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td colspan="10"><%= empty %></td>
                </tr>
            </tbody>
        </table>

        <%= pagination %>
    """
    events:
        "keypress .search-query": "updateSearchOnEnter"
        "click    .pager-prev":   "prevPage"
        "click    .pager-next":   "nextPage"
        "click    th":            "toggleSort"

    # Binds the collection update event for rendering
    initialize: ->
        @collection.on "reset", @renderData
        for key, val of @options
            if key != "el" and key != "collection"
                this[key] = val or this[key]
        @data = $.extend({}, @initialData, @parseQuery Backbone.history.fragment)
        @data.page = @page or 1
        @data.size = @size or 10
        return @

    # Navigate to url with new parameters in querystring
    updateUrl: (key, val) =>
        @router.navigate(@updateQueryString Backbone.history.fragment, key, val)

    # Return updated uri's querystring with key and value
    updateQueryString: (uri, key, val) ->
        re = new RegExp("([?|&])" + key + "=.*?(&|$)", "i")
        if uri.match(re)
            # TODO delete parameter if value is empty (taking care of the &/? thing)
            return uri.replace(re, "$1" + key + "=" + val + "$2")
        else
            separator = if uri.indexOf("?") != -1 then "&" else "?"
            return uri + separator + key + "=" + val

    # Return a parsed querystring with the "?" (eg. query = "/users?hi=1&bye=hello")
    # returns {hi: "1", bye: "hello"}
    parseQuery: (uri) ->
        ret = {}
        if (i = uri.indexOf("?")) >= 0
            uri    = uri.substring(i + 1)
            search = /([^&=]+)=?([^&]*)/g
            decode = (s) -> decodeURIComponent(s.replace(/\+/g, " "))
            while match = search.exec(uri)
               ret[decode(match[1])] = decode(match[2])
        return ret

    # Set data and update collection
    setData: (id, val) =>
        if val
            @data[id] = val
        else
            delete @data[id]
        if @router
            @updateUrl id, val
        @update()

    # Creates a filter from a filter config definition
    createFilter: (name, filter) =>
        switch filter.type
            when "option"
                return new ButtonOptionFilter
                    id: name
                    filterClass: filter.className or ""
                    options: filter.options
                    init: (filter.set or _.identity) @data[name] or filter.init or filter.options[0].value or filter.options[0]
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
                    className: "input-prepend inline"
                    filterClass: filter.className or ""
                    get: filter.get or _.identity
                    init: (filter.set or _.identity) @data[name] or filter.init or ""
                    setData: @setData
        # For custom filters, we just provide the setData function
        filter.setData = @setData
        filter.init = (filter.set or _.identity) @data[name] or filter.init or ""
        return filter

    # Update collection only if event was trigger by an enter
    updateSearchOnEnter: (e) =>
        if e.keyCode == 13
            @setData @search.query or "q", e.currentTarget.value
        return @

    # Update the collection given all the options/filters
    update: =>
        @collection.fetch data: @data
        return @

    # Render the collection in the tbody section of the table
    renderData: =>
        $("tbody", @$el).html @dataTemplate
            collection: @collection
            columns:    @columns
            empty:      @empty or "No records to show"
        return @

    # Go to the previous page in the collection
    prevPage: =>
        if @data.page > 1
            @data.page = @data.page - 1
            $(".page", @$el).html @data.page
            @update()

    # Go to the next page in the collection
    nextPage: =>
        # Since we don't have a collection count, for now we use the size of
        # the last GET as an heuristic to limit the use of nextPage
        if @collection.length == @data.size
            @data.page = @data.page + 1
            $(".page", @$el).html @data.page
            @update()

    # Toggle/Select sort column and direction, and update table accodingly
    toggleSort: (e) =>
        el = e.currentTarget
        cl = el.className
        if cl.indexOf("sorting_desc") >= 0
            @data.sort_dir = "asc"
            cl = "sorting_asc"
        else if cl.indexOf("sorting") >= 0 or cl.indexOf("sorting_asc") >= 0
            @data.sort_dir = "desc"
            cl = "sorting_desc"
        else
            return @
        $("th", @$el).removeClass("sorting_desc sorting_asc")
        $(el, @$el).addClass(cl)
        @data.sort_col = el.abbr
        @update()

    # Apply a template to a model and return the result (string), or empty
    # string if model is false/undefined
    applyTemplate: (template, model) ->
        (model and template model: model) or ""

    # Render skeleton of the table, creating filters and other additions,
    # and trigger an update of the collection
    render: =>
        @$el.html @template
            columns:    @columns
            empty:      @empty or ""
            title:      @applyTemplate @titleTemplate,      @title
            search:     @applyTemplate @searchTemplate,     @search
            pagination: @applyTemplate @paginationTemplate, @pagination

        @filters = _.map(@filters, (filter, name) => @createFilter(name, filter))
        filtersDiv = $(".filters", @$el)
        _.each @filters, (filter) -> filtersDiv.append filter.render().el, " "
        @update()

###
Filters
-------
###

class Filter extends Backbone.View
    tagName: "div"
    className: "inline"

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
    events:
        "change .filter": "update"

    update: (e) =>
        @setData @id, @options.get e.currentTarget.value

class ButtonFilter extends Filter
    template: _.template """
        <button type="button" class="filter btn <%= init == on ? "active" : "" %> <%= filterClass %>" data-toggle="button"><%= name %></button>
    """
    events:
        "click .filter": "update"

    initialize: ->
        super
        @values = [@options.off, @options.on]
        @current = if @options.init == @options.off then 0 else 1

    update: =>
        @current = 1 - @current
        @setData @id, @values[@current]

class ButtonOptionFilter extends Filter
    template: _.template """
        <div class="btn-group <%= filterClass %>" data-toggle="buttons-radio">
            <% _.each(options, function (el, i) { %>
                <button class="btn <%= init == el.value ? "active" : "" %>" value="<%= el.value %>"><%= el.name %></button>
            <% }) %>
        </div>
    """
    events:
        "click .btn": "update"

    initialize: ->
        super
        @options.options = _.map @options.options,
            (option) => {name: @prettyName(option.name || option), value: option.value or option}

    update: (e) =>
        @setData @id, e.currentTarget.value
