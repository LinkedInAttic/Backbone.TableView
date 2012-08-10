class Backbone.TableView extends Backbone.View
    tagName: "div"
    titleTemplate: _.template "<h2><%= model %></h2>"
    filtersTemplate: _.template """
        <% _.each(model, function (filter) { %>
            <%= filter %>
        <% }) %>
    """
    searchTemplate: _.template """
        <input type="text" class="search-query pull-right" placeholder="<%= model.detail || model %>"></input>
    """
    inputTemplate: _.template """
        <div class="input-prepend inline">
            <span class="add-on"><%= name %></span><input id="<%= id %>" type="text" class="filter <%= className %>" value="<%= init %>"></input>
        </div>
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

            <div class="controls pagination-centered span8">
                <%= filters %>
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
        "keypress .search-query": "updateOnEnter"
        "change   .filter":       "update"
        "click    .pager-prev":   "prevPage"
        "click    .pager-next":   "nextPage"
        "click    th":            "toggleSort"

    initialize: ->
        @collection.on "reset", @renderData
        @page = @page or 1
        @size = @size or 10
        return @

    printFilter: (name, filter) =>
        switch filter.type
            when "input"
                return @inputTemplate
                    name: @capitalize(name)
                    id: "filter" + name
                    init: filter.init or ""
                    className: filter.className or ""
        return ""

    updateOnEnter: (e) =>
        if e.keyCode == 13 then @update()
        return @

    update: =>
        data = {}
        for key, val of @initialData
            data[key] = val
        for filter, options of @filters
            field = $("#filter" + filter, @$el)
            if field
                val = field.val()
                data[filter] = (options.get? and options.get(val)) or val
        if @search
            data[@search.query or "q"] = $(".search-query", @$el).val()
        if @sortDir and @sortCol
            data.sort_dir = @sortDir
            data.sort_col = @sortCol
        data.page = @page
        data.size = @size
        @collection.fetch data: data
        return @

    capitalize: (str) ->
        str.charAt(0).toUpperCase() + str.substring(1).toLowerCase()

    renderData: =>
        $elData = $("tbody", @$el)
        if $elData
            $elData.html @dataTemplate
                collection: @collection
                columns:    @columns
                empty:      @empty or ""
        $(".page", @$el).html @page
        return @

    prevPage: =>
        @page = @page - 1
        if @page < 1
            @page = 1
        else
            @update()

    nextPage: =>
        # Since we don't have a collection count, for now we use the size of
        # the last GET as an heuristic to limit the use of nextPage
        if @collection.length == @size
            @page = @page + 1
            @update()

    toggleSort: (e) =>
        el = e.currentTarget
        cl = el.className
        if cl.indexOf("sorting_desc") >= 0
            @sortDir = "asc"
            cl = "sorting_asc"
        else if cl.indexOf("sorting") >= 0 or cl.indexOf("sorting_asc") >= 0
            @sortDir = "desc"
            cl = "sorting_desc"
        else
            return @
        $("th.sorting_desc, th.sorting_asc", @$el).removeClass("sorting_desc sorting_asc")
        $(el, @$el).addClass(cl)
        @sortCol = el.abbr
        @update()

    applyTemplate: (template, model) ->
        (model? and model and template model: model) or ""

    render: =>
        @$el.html @template
            columns:    @columns
            empty:      @empty or ""
            title:      @applyTemplate @titleTemplate,      @title
            search:     @applyTemplate @searchTemplate,     @search
            filters:    @applyTemplate @filtersTemplate,    _.map(@filters, (filter, name) => @printFilter name, filter)
            pagination: @applyTemplate @paginationTemplate, @pagination
        @update()
