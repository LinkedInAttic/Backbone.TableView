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

    initialize: ->
        @collection.on "reset", @renderData
        @data = @options.initialData or @initialData or {}
        @data.page = @options.page or @page or 1
        @data.size = @options.size or @size or 10
        return @

    setData: (id, val) =>
        @data[id] = val
        @update()

    createFilter: (name, filter) =>
        switch filter.type
            when "input"
                return new InputFilter
                    id: name
                    init: filter.init or ""
                    className: "input-prepend inline"
                    filterClass: filter.className or ""
                    get: filter.get or _.identity
                    setData: @setData
        # For custom filters, we just provide the setData function
        filter.setData = @setData
        return filter

    updateSearchOnEnter: (e) =>
        if e.keyCode == 13
            val = e.currentTarget.value
            if val
                @data[@search.query or "q"] = val
            else
                delete @data[@search.query or "q"]
            @update()
        return @

    update: =>
        @collection.fetch data: @data
        return @

    renderData: =>
        $("tbody", @$el).html @dataTemplate
            collection: @collection
            columns:    @columns
            empty:      @empty or "No records to show"
        return @

    prevPage: =>
        if @data.page > 1
            @data.page = @data.page - 1
            $(".page", @$el).html @data.page
            @update()

    nextPage: =>
        # Since we don't have a collection count, for now we use the size of
        # the last GET as an heuristic to limit the use of nextPage
        if @collection.length == @data.size
            @data.page = @data.page + 1
            $(".page", @$el).html @data.page
            @update()

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
        $("th.sorting_desc, th.sorting_asc", @$el).removeClass("sorting_desc sorting_asc")
        $(el, @$el).addClass(cl)
        @data.sort_col = el.abbr
        @update()

    applyTemplate: (template, model) ->
        (model and template model: model) or ""

    render: =>
        @$el.html @template
            columns:    @columns
            empty:      @empty or ""
            title:      @applyTemplate @titleTemplate,      @title
            search:     @applyTemplate @searchTemplate,     @search
            pagination: @applyTemplate @paginationTemplate, @pagination

        @filters = _.map(@filters, (filter, name) => @createFilter(name, filter))
        filtersDiv = $(".filters", @$el)
        _.each @filters, (filter) ->
            filtersDiv.append filter.render().el
            filtersDiv.append " "
        @update()

class Filter extends Backbone.View
    tagName: "div"
    className: "inline"

    initialize: ->
        @id = @options.id
        @setData = @options.setData

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
