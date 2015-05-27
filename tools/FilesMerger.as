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
			RawObjectsWorks.deserialize(resultObject, mergeDialogsAndMainMenu(_parsedFilesByName), true);

			saveMergedOnDisk(resultObject);
		}

		private function mergeTexts(scenarios:Object):Object
		{
			var resultTextsCollection:Object = {};
			var textsCounter:int = 1;
			for each(var scenarioObject:Object in scenarios) {
				var textsObj:Object = scenarioObject['texts'];
				var textIds:Array = RawObjectsWorks.getKeys(textsObj);
				var count:int = textIds.length;

				for (var i:int = 0; i < count; i++) {
					var newId:String = String(textsCounter);
					var countBefore:int = textIds.length;
					var throughRemove:Boolean;

					if (textsObj[newId] != null && textIds.indexOf(newId) > -1) {
						throughRemove = true;
						resultTextsCollection[newId] = textsObj[newId];
						ArrayUtil.removeValueFromArray(textIds, newId)
					} else {
						throughRemove = false;
						var textId:String = textIds.pop();
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

					if (countBefore == textIds.length) {
						assert(false, 'Pumm');
					}

					textsCounter++;
				}

				assert(textIds.length == 0, "Something goes wrong");
			}

			return resultTextsCollection;
		}

		private function mergeDialogsAndMainMenu(scenarios:Object):Object
		{
			var resultDialog:Array = [];
			var resultMainMenu:Array = [];
			var nextGuid:int = 1;

			for each(var scenarioObject:Object in scenarios) {
				var dialogArray:Array = scenarioObject['dialog'];
				var count:int = dialogArray.length;

				while (count--) {
					var newId:String = String(nextGuid);
					var currentDialogPoint:Object = dialogArray[count];
					var oldId:String = currentDialogPoint['guid'];

					resultDialog.push(currentDialogPoint);

					RawObjectsWorks.forEach(
							function (obj:Object, propName:String, propValue:Object):void
							{
								if ((propName == 'to' || propName == 'guid') && propValue == newId) {
									obj[propName] = 'old' + newId;
								}
							},
							dialogArray, true);

					RawObjectsWorks.forEach(
							function (obj:Object, propName:String, propValue:Object):void
							{
								if ((propName == 'to' || propName == 'guid') && propValue == oldId) {
									obj[propName] = int(newId);
								}
							},
							dialogArray, true);

					RawObjectsWorks.forEach(
							function (obj:Object, propName:String, propValue:Object):void
							{
								if (propName == 'guid' && propValue == oldId) {
									obj[propName] = int(newId);
								}
							},
							scenarioObject['mainMenu'], true);

					nextGuid++;
				}

				resultMainMenu = resultMainMenu.concat(scenarioObject['mainMenu']);
			}

			return {dialog: resultDialog, mainMenu: resultMainMenu};
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
