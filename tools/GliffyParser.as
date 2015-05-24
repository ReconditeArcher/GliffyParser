package tools
{
	import net.jimblacker.sprintf;
	import net.reconditeden.debug.assert;
	import net.reconditeden.text.HtmlWorks;
	import net.reconditeden.utils.PseudoJSONConverter;
	import net.reconditeden.utils.RawObjectsWorks;

	/**
	 * @author Ilya Sakhatskiy
	 */
	public class GliffyParser
	{
		private const VALID_CLIENT_DATA_PROPS:Array = ['place', 'bgUrl', 'skipInAnswers', 'npcName', 'menuItem', 'unique'];
		private const BACK_LINK_NAME:String = '__parent__';
		private const SCENARIO_POINT_UIDS:Array = ['com.gliffy.shape.basic.basic_v1.default.square', 'com.gliffy.shape.basic.basic_v1.default.rectangle'];
		private const SCENARIO_WAYPOINT_UIDS:Array = ['com.gliffy.shape.basic.basic_v1.default.circle'];

		private const CLIENT_DATA_OPENING_SYMBOL:String = '{';
		private const CLIENT_DATA_CLOSING_SYMBOL:String = '}';

		private var _objectsById:Object = {};
		private var _textObjects:Object = {};
		private var _linksByStartUid:Object = {};
		private var _linksByEndUid:Object = {};
		private var _pointObjects:Object = {};
		private var _waypointObjects:Object = {};

		private var _resultObj:Object = {};

		private var _pseudoJSONConverter:PseudoJSONConverter;

		public function GliffyParser()
		{
			_resultObj = createEmptyScenario();
			_objectsById = {};

			_pseudoJSONConverter = new PseudoJSONConverter();
		}

		public function convert(gliffyJson:String):String
		{
			traverseTree(JSON.parse(gliffyJson));
			pickMeaningfulObjects();
			linkObjects();

			_resultObj['texts'] = createTextsPart();

			var resultScenario:String = getScenarioStrng();
			return resultScenario;
		}

		private function linkObjects():void
		{
			for each (var scenarioPoint:Object in _pointObjects) {
				var guid:String = scenarioPoint['guid'];
				if (scenarioPoint['menuItem'] != null) {
					(_resultObj['mainMenu'] as Array).push({guid: guid, text: scenarioPoint['menuItem']});
					delete scenarioPoint['menuItem'];
				}

				var links:Array = _linksByStartUid[guid] as Array;
				if (links) {
					for each (var link:Object in links) {
						if (!link || !isMeaningful(_objectsById[link['end']])) continue;

						var waypoint:Object = _waypointObjects[link['end']];
						if (waypoint) {
							(scenarioPoint['points'] as Array).push(waypoint);

							var linksFromThisWaypoint:Array = _linksByStartUid[link['end']];
							if (linksFromThisWaypoint && linksFromThisWaypoint[0]) {
								waypoint['to'] = linksFromThisWaypoint[0]['end'];
							}
						}
					}
				}
			}
		}

		private function pickMeaningfulObjects():void
		{
			for each (var textObj:Object in _textObjects) {
				var i:int = 5;
				var parent:Object = textObj;
				do {
					parent = parent[BACK_LINK_NAME];
					i--;
				} while (!isMeaningful(parent) && i > 0);

				if (objectHasPropWithAnyValue(parent, 'uid', SCENARIO_POINT_UIDS)) {
					createDialogPoint(parent, textObj);
				} else if (objectHasPropWithAnyValue(parent, 'uid', SCENARIO_WAYPOINT_UIDS)) {
					createDialogWaypoint(parent, textObj);
				}
			}
		}

		private function createDialogWaypoint(dialogWaypointSource:Object, textObj:Object):void
		{
			var data:Object = {};
			var text:String = textObj['Text']['html'];
			var dataStartIndex:int = text.indexOf(CLIENT_DATA_OPENING_SYMBOL);
			var dataEndIndex:int = text.lastIndexOf(CLIENT_DATA_CLOSING_SYMBOL);
			if (dataStartIndex > -1 || dataEndIndex > -1) {
				assert(dataStartIndex > 0, 'Warning! Closing curly bracket without opening one!');
				assert(dataEndIndex > 0, 'Warning! Opening curly bracket without closing one!');

				var clientDataString:String = text.substring(dataStartIndex, dataEndIndex + 1);
				clientDataString = stripHtml(clientDataString);

				data = _pseudoJSONConverter.parseStringToObjects(clientDataString);
				text = text.substring(0, dataStartIndex);
			}

			var scenarioWaypoint:Object = {};
			scenarioWaypoint['text'] = textObj[BACK_LINK_NAME]['id'];

			for each (var clientDataObj:Object in data) {
				var invalidProp:String = findInvalidProperties(clientDataObj);
				if (invalidProp) {
					assert(false, sprintf('Waypoint with text "%s" has inappropriate field "%s" in clientData', scenarioWaypoint['text'], invalidProp));
				}
				RawObjectsWorks.deserialize(scenarioWaypoint, clientDataObj, true);
			}

			assert(scenarioWaypoint['place'], sprintf('Point with text %s has no place', scenarioWaypoint['text']));

			_waypointObjects[dialogWaypointSource['id']] = scenarioWaypoint;
		}

		private function createDialogPoint(dialogPointSource:Object, textObj:Object):void
		{
			var data:Object = {};
			var text:String = textObj['Text']['html'];
			var dataStartIndex:int = text.indexOf(CLIENT_DATA_OPENING_SYMBOL);
			var dataEndIndex:int = text.lastIndexOf(CLIENT_DATA_CLOSING_SYMBOL);
			if (dataStartIndex > -1 || dataEndIndex > -1) {
				assert(dataStartIndex > 0, 'Warning! Closing curly bracket without opening one!');
				assert(dataEndIndex > 0, 'Warning! Opening curly bracket without closing one!');

				var clientDataString:String = text.substring(dataStartIndex, dataEndIndex + 1);
				clientDataString = stripHtml(clientDataString);

				data = _pseudoJSONConverter.parseStringToObjects(clientDataString);
				text = text.substring(0, dataStartIndex);
			}

			var scenarioPoint:Object = {};
			scenarioPoint['guid'] = dialogPointSource['id'];
			scenarioPoint['text'] = textObj[BACK_LINK_NAME]['id'];
			scenarioPoint['points'] = [];

			for each (var clientDataObj:Object in data) {
				var invalidProp:String = findInvalidProperties(clientDataObj);
				if (invalidProp) {
					assert(false, sprintf('Point with text "%s" has inappropriate field "%s" in clientData', scenarioPoint['text'], invalidProp));
				}
				RawObjectsWorks.deserialize(scenarioPoint, clientDataObj, true);
			}


			if (scenarioPoint['menuItem']) scenarioPoint['menuItem'] = stripHtml(scenarioPoint['menuItem']);
			if (scenarioPoint['npcName']) scenarioPoint['npcName'] = stripHtml(scenarioPoint['npcName']);

			(_resultObj['dialog'] as Array).push(scenarioPoint);
			_pointObjects[scenarioPoint['guid']] = scenarioPoint;
		}

		private function isMeaningful(testObject:Object):Boolean
		{
			if (!testObject) return false;

			var meanSmth:Boolean = objectHasPropWithAnyValue(testObject, 'uid', SCENARIO_POINT_UIDS);
			meanSmth ||= objectHasPropWithAnyValue(testObject, 'uid', SCENARIO_WAYPOINT_UIDS);

			return meanSmth;
		}

		private function createTextsPart():Object
		{
			var texts:Object = {};
			for (var id:String in _textObjects) {

				var text:String = stripHtml(_textObjects[id]['Text']['html']);
				var dataStartIndex:int = text.indexOf(CLIENT_DATA_OPENING_SYMBOL);
				var dataEndIndex:int = text.lastIndexOf(CLIENT_DATA_CLOSING_SYMBOL);
				if (dataStartIndex > -1 || dataEndIndex > -1) {
					assert(dataStartIndex > 0, 'Warning! Closing curly bracket without opening one!');
					assert(dataEndIndex > 0, 'Warning! Opening curly bracket without closing one!');

					text = text.substring(0, dataStartIndex);
				}

				texts[id] = text;
			}

			return texts;
		}

		private function traverseTree(sourceObject:Object):void
		{
			for (var propName:String in sourceObject) {
				// To avoid infinite loop
				if (propName == BACK_LINK_NAME) continue;

				var propValue:Object = sourceObject[propName];

				if (propValue == null) continue;

				createIdMap(propName, propValue, sourceObject);

				// Если свойство - ссылка на другой об-т - его тоже нужно протрейсить.
				if (typeof propValue == 'object') {
					includeBackLink(propValue, sourceObject);
					pickTextObjects(propValue);
					pickLinkObjects(propValue);

					traverseTree(propValue);
				}
			}
		}

		private function pickLinkObjects(propValue:Object):void
		{
			var constraints:Object = propValue['constraints'];
			if (constraints != null) {
				var startConstraint:Object = constraints['startConstraint'];
				var endConstraint:Object = constraints['endConstraint'];

				if (startConstraint != null && endConstraint != null) {
					var startNodeId:Object = startConstraint['StartPositionConstraint']['nodeId'];
					var endNodeId:Object = endConstraint['EndPositionConstraint']['nodeId'];

					var linkObj:Object = {start: startNodeId, end: endNodeId};

					RawObjectsWorks.addToMap(_linksByStartUid, linkObj, 'start');
					RawObjectsWorks.addToMap(_linksByEndUid, linkObj, 'end');
				}
			}
		}

		private function createIdMap(propName:String, propValue:Object, hostObject:Object):void
		{
			if (propName == 'id') {
				if (propValue == '0') {
					propValue = '1000000';
					hostObject[propName] = propValue;
				}
				checkIdCollision(String(propValue), _objectsById);
				_objectsById[propValue] = hostObject;
			}
		}

		private function includeBackLink(propValue:Object, hostObject:Object):void
		{
			if (typeof propValue == 'object') {
				propValue[BACK_LINK_NAME] = hostObject;
			}
		}

		private function pickTextObjects(obj:Object):void
		{
			if (objectHasProp(obj, 'type', 'Text')) {
				var parentId:String = obj[BACK_LINK_NAME]['id'];
				checkIdCollision(parentId, _textObjects);

				_textObjects[parentId] = obj;
			}
		}

		private function checkIdCollision(key:String, map:Object):void
		{
			assert(map[key] == null, 'Map already contains obj with key: ' + key);
		}

		private function objectHasProp(checkObject:Object, propName:String, propValue:Object):Boolean
		{
			return checkObject != null && checkObject[propName] != null && checkObject[propName] == propValue;
		}

		private function objectHasPropWithAnyValue(checkObject:Object, propName:String, validPropValues:Array):Boolean
		{
			var result:Boolean = false;
			var objectHasProp:Boolean = checkObject != null && checkObject[propName] != null;
			if (objectHasProp) {
				for each (var value:String in validPropValues) {
					if (checkObject[propName] == value) {
						result = true;
						break;
					}
				}
			}
			return result;
		}

		private function getScenarioStrng():String
		{
			return JSON.stringify(_resultObj);
		}

		private function createEmptyScenario():Object
		{
			var emptyScenario:Object = {};
			emptyScenario['texts'] = {};
			emptyScenario['mainMenu'] = [];
			emptyScenario['dialog'] = [];

			return emptyScenario;
		}

		private function stripHtml(sourceString:String):String
		{
			if (!sourceString) return sourceString;

			return HtmlWorks.stripTagsAndEntities(sourceString);
		}

		private function findInvalidProperties(objToValidate:Object):String
		{
			var invalidProperty:String = null;
			for (var propName:String in objToValidate) {
				var propIsValid:Boolean = VALID_CLIENT_DATA_PROPS.indexOf(propName) > -1;
				if (!propIsValid) {
					invalidProperty = propName;
					break;
				}
			}

			return invalidProperty;
		}

	}
}
