all: coffee minify

coffee:
	coffee -c backbone.tableview.coffee

minify: coffee
	closure-compiler backbone.tableview.js > backbone.tableview.min.js
