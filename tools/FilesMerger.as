package tools
{
	import com.adobe.utils.ArrayUtil;

	import flash.events.Event;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.net.FileReferenceList;
	import flash.utils.ByteArray;

	import net.reconditeden.debug.assert;
	import net.reconditeden.utils.RawObjectsWorks;

	/**
	 * @author ReconditeArcher (Sakhatskiy Ilya)
	 */
	public class FilesMerger
	{
		private var _fileFilter:FileFilter;
		private var _fileReferenceList:FileReferenceList;
		private var _filesList:Array;
		private var _fileReference:FileReference;
		private var _parsedFilesByName:Object = {};

		public function FilesMerger()
		{
			init();
		}

		public function mergeFiles():void
		{
			_fileReferenceList.addEventListener(Event.SELECT, onFilesSelected);
			_fileReferenceList.browse([_fileFilter]);
		}

		private function onFilesSelected(e:Event):void
		{
			_fileReferenceList.removeEventListener(Event.SELECT, onFilesSelected);
			_filesList = _fileReferenceList.fileList;

			loadNextFile();
		}

		private function loadNextFile():void
		{
			if (_filesList.length) {
				_fileReference = (_filesList.pop() as FileReference);
				_fileReference.addEventListener(Event.COMPLETE, onFileLoaded);
				_fileReference.load();
			} else {
				onAllFileLoaded();
			}
		}

		private function onFileLoaded(e:Event):void
		{
			_fileReference.removeEventListener(Event.COMPLETE, onFileLoaded);

			var fileData:ByteArray = e.target.data as ByteArray;
			var jsonString:String = fileData.readUTFBytes(fileData.length);
			_parsedFilesByName[_fileReference.name] = JSON.parse(jsonString);

			loadNextFile();
		}

		private function onAllFileLoaded():void
		{
			var resultObject:Object = {};

			resultObject['texts'] = mergeTexts(_parsedFilesByName);
			RawObjectsWorks.deserialize(resultObject, mergeDialogsAndMainMenu(_parsedFilesByName, resultObject['texts']), true);

			saveMergedOnDisk(resultObject);
		}

		public function mergeTexts(scenarios:Object):Object
		{
//			var linksHistory:Dictionary = new Dictionary();

			var resultTextsCollection:Object = {};
			var textsCounter:int = 1;
			for each(var scenarioObject:Object in scenarios) {
				var textsObj:Object = scenarioObject['texts'];
				var textIds:Array = RawObjectsWorks.getKeys(textsObj);
				var count:int = textIds.length;

//				RawObjectsWorks.forEach(
//					function (obj:Object, propName:String, propValue:Object):void {
//						if (propName == 'text' && !linksHistory[obj]) {
//							linksHistory[obj] = { text: textsObj[propValue], textId: propValue };
//						}
//					},
//				scenarioObject['dialog'], true);


				for (var i:int = 0; i < count; i++) {
					var newId:String = String(textsCounter);

					if (textsObj[newId] != null && textIds.indexOf(newId) > -1) {
						resultTextsCollection[newId] = textsObj[newId];
						ArrayUtil.removeValueFromArray(textIds, newId)
					} else {
						var textId:String = textIds.pop();
						RawObjectsWorks.forEach(
								function (obj:Object, propName:String, propValue:Object):void
								{
									if ((propName == 'text') && propValue == newId) {
										obj[propName] = 'old' + newId;
									}
								},
								scenarioObject['dialog'], true);

						RawObjectsWorks.forEach(
								function (obj:Object, propName:String, propValue:Object):void
								{
									if (propName == 'text' && propValue == textId) {
										obj[propName] = newId;
									}
								},
								scenarioObject['dialog'], true);
						resultTextsCollection[newId] = textsObj[textId];
					}

					textsCounter++;
				}

				assert(textIds.length == 0, "Something goes wrong");
			}

//			for each(var scenarioObject:Object in scenarios) {
//				RawObjectsWorks.forEach(
//					function (obj:Object, propName:String, propValue:Object):void {
//						if (propName == 'text' && linksHistory[obj]) {
//							assert(linksHistory[obj]['text'] == resultTextsCollection[propValue], 'Shit happens');
//						}
//					},
//				scenarioObject['dialog'], true);
//			}

			return resultTextsCollection;
		}

		private function mergeDialogsAndMainMenu(scenarios:Object, textsObj:Object):Object
		{
//			var linksHistory:Dictionary = new Dictionary();

			var resultDialog:Array = [];
			var resultMainMenu:Array = [];
			var nextGUID:int = 1;

			for each(var scenarioObject:Object in scenarios) {
				var dialogArray:Array = scenarioObject['dialog'];

				// { Test code
//				RawObjectsWorks.forEach(
//					function (obj:Object, propName:String, propValue:Object):void {
//						if (propName == 'to') {
//							assert(!linksHistory[obj], 'Same object detected twice');
//							var pointingPoint:Object = findObjectWithGUID(dialogArray, int(propValue));
//
//							trace('to: ' + propValue + ' WayPoint with text: ' + textsObj[obj['text']] + ' points to point with text: ' + textsObj[pointingPoint['text']]);
//							linksHistory[obj] = textsObj[pointingPoint['text']];
//						}
//					},
//				dialogArray, true);
				// } End Test code

				RawObjectsWorks.forEach(
						function (obj:Object, propName:String, propValue:Object):void
						{
							if ((propName == 'to' || propName == 'guid')) {
								obj[propName] = 'old' + propValue;
							}
						},
						scenarioObject, true);

				for each (var currentDialogPoint:Object in dialogArray) {
					var newId:String = String(nextGUID);
					var oldId:String = currentDialogPoint['guid'];

					resultDialog.push(currentDialogPoint);

					RawObjectsWorks.forEach(
							function (obj:Object, propName:String, propValue:Object):void
							{
								if ((propName == 'to' || propName == 'guid') && propValue == oldId) {
									obj[propName] = int(newId);
								}
							},
							scenarioObject, true);

					nextGUID++;
				}

				resultMainMenu = resultMainMenu.concat(scenarioObject['mainMenu']);
			}

			// { Test code
//			RawObjectsWorks.forEach(
//				function (obj:Object, propName:String, propValue:Object):void {
//					if (propName == 'to' && linksHistory[obj]) {
//						var pointingPoint:Object = findObjectWithGUID(resultDialog, int(propValue));
//
//						trace('Everything is fine: ' + (linksHistory[obj] == textsObj[pointingPoint['text']]));
//						if (linksHistory[obj] != textsObj[pointingPoint['text']]) {
//							trace('to: ' + propValue + ' WayPoint with text: ' + textsObj[obj['text']] + ' points on point with text: ' + textsObj[pointingPoint['text']]);
//							trace('But it used to point on: ' + textsObj[linksHistory[obj]['text']]);
//						}
//					}
//				},
//			resultDialog, true);
			// } End Test code

			return {dialog: resultDialog, mainMenu: resultMainMenu};
		}

		private function findObjectWithGUID(objects:Array, guid:int):Object
		{
			return objects.filter(function (point:Object, ...rest):Boolean { return point['guid'] == guid; })[0];
		}

		private function saveMergedOnDisk(mergedDialogs:Object):void
		{
			var jsonStringAll:String = JSON.stringify(mergedDialogs);
			_fileReference.save(jsonStringAll, "Content.txt");
		}

		private function init():void
		{
			_fileFilter = new FileFilter("Select files to merge", "*.*");
			_fileReferenceList = new FileReferenceList();
		}
	}
}
