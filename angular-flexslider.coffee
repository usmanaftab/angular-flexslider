'use strict'

angular.module('angular-flexslider', [])
	.directive 'flexSlider', ($parse, $timeout) ->
		restrict: 'AE'
		scope: no
		replace: yes
		transclude: yes
		template: '<div class="flexslider-container"></div>'
		compile: (element, attr, linker) ->
			match = attr.slide.match /^\s*(.+)\s+in\s+(.*?)(?:\s+track\s+by\s+(.+?))?\s*$/
			indexString = match[1]
			collectionString = match[2]
			trackBy = if angular.isDefined(match[3]) then $parse(match[3]) else $parse("#{indexString}")

			flexsliderDiv = null
			slidesItems = {}

			($scope, $element) ->
				getTrackFromItem = (collectionItem) ->
					locals = {}
					locals[indexString] = collectionItem
					trackBy($scope, locals)

				addSlide = (collectionItem, callback) ->
					# Generating tracking element
					track = getTrackFromItem collectionItem
					# See if it's unique
					if slidesItems[track]?
						throw "Duplicates in a repeater are not allowed. Use 'track by' expression to specify unique keys."
					# Create new item
					childScope = $scope.$new()
					childScope[indexString] = collectionItem
					linker childScope, (clone) ->
						slideItem =
							collectionItem: collectionItem
							childScope: childScope
							element: clone
						slidesItems[track] = slideItem
						callback?(slideItem)

				removeSlide = (collectionItem) ->
					track = getTrackFromItem collectionItem
					slideItem = slidesItems[track]
					return unless slideItem?
					delete slidesItems[track]
					slideItem.childScope.$destroy()
					slideItem

				$scope.$watchCollection collectionString, (collection) ->

					# Early exit if no collection
					return unless collection?.length

					# If flexslider is already initialized, add or remove slides
					if flexsliderDiv?
						slider = flexsliderDiv.data 'flexslider'
						currentSlidesLength = Object.keys(slidesItems).length
						# Get an associative array of track to collection item
						collection ?= []
						trackCollection = {}
						for c in collection
							trackCollection[c] = getTrackFromItem c
						# Generates arrays of collection items to add and remvoe
						toAdd = (c for c in collection when not slidesItems[trackCollection[c]]?)
						toRemove = (i.collectionItem for t, i of slidesItems when not trackCollection[t]?)
						# Workaround to a still unresolved problem in using flexslider.addSlide
						if (toAdd.length == 1 and toRemove.length == 0) or toAdd.length == 0
							# Remove items
							for e in toRemove
								e = removeSlide e
								slider.removeSlide e.element
							# Add items
							for e in toAdd
								addSlide e, (item) ->
									idx = collection.indexOf(e)
									idx = undefined if idx == currentSlidesLength
									$scope.$evalAsync ->
										slider.addSlide(item.element, idx)
							# Early exit
							return

					# Create flexslider container
					slidesItems = {}
					flexsliderDiv?.remove()
					slides = angular.element('<ul class="slides"></ul>')
					flexsliderDiv = angular.element('<div class="flexslider"></div>')
					flexsliderDiv.append slides
					$element.append flexsliderDiv

					# Generate slides
					addSlide(c, (item) -> slides.append item.element) for c in collection

					# Options are derived from flex-slider arguments
					options = {}
					for attrKey, attrVal of attr
						if attrKey.indexOf('$') == 0
							continue
						unless isNaN(n = parseInt(attrVal))
							options[attrKey] = n
							continue
						if attrVal in ['false', 'true']
							options[attrKey] = attrVal is 'true'
							continue
						if attrKey in ['start', 'before', 'after', 'end', 'added', 'removed']
							options[attrKey] = do (attrVal) ->
								f = $parse(attrVal)
								-> $scope.$apply -> f($scope, {})
							continue
						options[attrKey] = attrVal

					# Running flexslider
					$timeout (-> flexsliderDiv.flexslider options), 0
