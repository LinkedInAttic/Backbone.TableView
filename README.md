# Backbone.TableView

Backbone View to render collections as tables. Currently it is targeted at
bootstrap users, in the future it will be more css agnostic.

## How To Use

Subclass TableView and add column definitions. Optionaly
you can add a title, a search bar, pagination, and any number
of filters (see supported filters below):

    class UserTableView extends Backbone.TableView
        title: "My Users Table"
        columns:
            name:
                header: "My Name"
            type:
                header: "Type"
            last_login:
                header: "Last Login Time"
                draw: (model) ->
                    new Date(model.get "time")
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

Use it as any other Backbone View, either setting the "el" property at
creation, or letting backbone create if for you, eg (Users is a regular
backbone collection):

    user_table = new UserTableView collection: new Users()
    $("#somewhere").html user_table.render().el

## License

Apache Public License (APL) 2.0

## Author

Juan Pablo Bottaro - https://github.com/jpbottaro

## Demo

[http://jsfiddle.net/jpbottaro/u7zQT/](http://jsfiddle.net/jpbottaro/u7zQT/)

## Thanks

This was initialy inspired by the project https://github.com/jsvine/Backbone.Table
