import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/constants/constants.dart';
import '../data/extension.dart';
import '../data/model/model_message.dart';
import '../data/model/model_page.dart';
import '../data/model/model_tag.dart';
import '../data/repository/messages_repository.dart';

part 'screen_message_state.dart';

class ScreenMessageCubit extends Cubit<ScreenMessageState> {
  final MessagesRepository repository;

  final controller = TextEditingController();

  ScreenMessageCubit({
    this.repository,
    DateTime time,
  }) : super(
          ScreenMessageState(
            fromDate: time,
            fromTime: TimeOfDay.fromDateTime(time),
            isReset: false,
            mode: Mode.await,
            counter: 0,
            isBookmark: false,
            list: <ModelMessage>[],
            enabledController: true,
            floatingBar: FloatingBar.nothing,
            indexCategory: -1,
            iconDataPhoto: Icons.photo_camera,
            curTag: '',
            listTag: ModeListTag.nothing,
            isStartAnim: <bool>[false, false, false, false],
          ),
        ) {
    controller.addListener(
      () => controller.text.isEmpty
          ? emit(
              state.copyWith(
                iconDataPhoto: Icons.photo_camera,
                onAddMessage:
                    state.mode == Mode.input ? showPhotoOption : ediTextMessage,
              ),
            )
          : emit(
              state.copyWith(
                iconDataPhoto: Icons.add,
                onAddMessage:
                    state.mode == Mode.input ? addMessage : ediTextMessage,
              ),
            ),
    );
    controller.addListener(showListTags);
    controller.addListener(closeListTags);
    controller.addListener(updateCurTag);
    controller.addListener(updateListTag);
    downloadTag();
  }

  void downloadTag() async {
    emit(
      state.copyWith(
        tags: await repository.tags(),
      ),
    );
  }

  void downloadMsg(ModelPage page) async {
    emit(
      state.copyWith(
        page: page,
        mode: Mode.input,
        list: await repository.messages(page.id),
        tags: await repository.tags(),
        onAddCategory: showCategoryList,
      ),
    );
  }

  void showListTags() {
    if (controller.text.endsWith('#') && state.floatingBar != FloatingBar.tag) {
      emit(
        state.copyWith(
          floatingBar: FloatingBar.tag,
          listTag: ModeListTag.listTags,
          curTag: '#',
          isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
            if (index == 2) return true;
            return state.isStartAnim[index];
          }),
        ),
      );
    }
  }

  void updateListTag() {
    if (state.floatingBar == FloatingBar.tag) {
      for (var i = 0; i < state.tags.length; i++) {
        if (state.tags[i].name.contains(state.curTag)) {
          state.tags[i] = state.tags[i].copyWith(isShow: true);
        } else {
          state.tags[i] = state.tags[i].copyWith(isShow: false);
        }
      }
      if (state.tags.where((element) => element.isShow).isEmpty) {
        emit(state.copyWith(listTag: ModeListTag.newTag, tags: state.tags));
      } else {
        emit(state.copyWith(tags: state.tags, listTag: ModeListTag.listTags));
      }
    }
  }

  void updateCurTag() {
    if (state.floatingBar == FloatingBar.tag) {
      var text = controller.text;
      var i = text.lastIndexOf('#');
      var iSpace = text.lastIndexOf(' ', i);
      var lastIndex = iSpace > i ? iSpace : text.length;
      emit(state.copyWith(curTag: text.substring(i, lastIndex)));
    }
  }

  void closeListTags() {
    if (!controller.text.contains('#') ||
        (state.curTag.isNotEmpty && controller.text.endsWith(' '))) {
      emit(
        state.copyWith(
          listTag: ModeListTag.nothing,
          floatingBar: state.attachedPhotoPath.isEmpty
              ? FloatingBar.nothing
              : FloatingBar.attach,
          isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
            if (index == 3 && state.attachedPhotoPath.isNotEmpty) return true;
            return state.isStartAnim[index];
          }),
        ),
      );
    }
  }

  void showBookmarkMessage() {
    emit(state.copyWith(isBookmark: !state.isBookmark));
  }

  void addTagToText(int index) {
    final text = '${controller.text}${state.tags[index].name.substring(1)} ';
    controller.value = controller.value.copyWith(
      text: text,
      selection:
          TextSelection(baseOffset: text.length, extentOffset: text.length),
      composing: TextRange.empty,
    );
  }

  void addMessage() async {
    final listTags = controller.text
        .split(' ')
        .where((element) => element.startsWith('#'))
        .toList();
    if (listTags.isNotEmpty) {
      for (var i = 0; i < listTags.length; i++) {
        var tag = ModelTag(
          name: listTags[i],
          isSelected: false,
          isShow: true,
        );
        if (!state.tags.contains(tag)) {
          var id = await repository.addTag(tag);
          state.tags.add(tag.copyWith(id: id));
        }
      }
    }
    var newMsg = ModelMessage(
      pageId: state.page.id,
      text: controller.text,
      isFavor: state.isBookmark,
      isSelected: false,
      indexCategory: state.indexCategory,
      photo: state.attachedPhotoPath,
      pubTime: state.isReset
          ? state.fromDate.applied(state.fromTime)
          : DateTime.now(),
    );
    var id = await repository.addMessage(newMsg);
    state.list.add(newMsg.copyWith(id: id));
    state.list.sort();
    controller.text = '';
    emit(
      state.copyWith(
        list: state.list,
        indexCategory: -1,
        floatingBar: FloatingBar.nothing,
        iconDataPhoto: Icons.photo_camera,
        onAddMessage: showPhotoOption,
        curTag: '',
        tags: state.tags,
        listTag: ModeListTag.nothing,
      ),
    );
  }

  void toSelectionAppBar(int index) {
    selection(index);
    emit(
      state.copyWith(
        mode: Mode.selection,
        enabledController: false,
      ),
    );
  }

  void toInputAppBar() {
    emit(
      state.copyWith(
        mode: Mode.input,
        enabledController: true,
        list: state.list,
        counter: 0,
        indexCategory: -1,
        onAddCategory: showCategoryList,
        iconDataPhoto: Icons.photo_camera,
        onAddMessage: showPhotoOption,
        floatingBar: FloatingBar.nothing,
        attachedPhotoPath: '',
      ),
    );
  }

  List<List<ModelMessage>> get groupMsgByDate {
    var list = <List<ModelMessage>>[];
    var temp = <ModelMessage>[];
    if (state.list.length == 1) {
      temp.add(state.list[0]);
      list.add(List.from(temp));
      return list;
    }
    for (var i = 0; i < state.list.length - 1; i++) {
      temp.add(state.list[i]);
      if (!state.list[i].pubTime.isSameDateByDay(state.list[i + 1].pubTime)) {
        list.add(List.from(temp));
        temp = <ModelMessage>[];
      }
    }
    if (state.list.isNotEmpty) {
      temp.add(state.list[state.list.length - 1]);
      list.add(List.from(temp));
    }
    return list;
  }

  Future<void> attachedPhoto(ImageSource source) async {
    final pickedFile = await ImagePicker().getImage(source: source);
    emit(
      state.copyWith(
        attachedPhotoPath: pickedFile.path,
        floatingBar: FloatingBar.attach,
        isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
          if (index == 3) return true;
          return state.isStartAnim[index];
        }),
        onAddMessage: showPhotoOption,
      ),
    );
  }

  void selection(int index) {
    var isSelected = state.list[index].isSelected;
    state.list[index] = state.list[index].copyWith(isSelected: !isSelected);
    if (isSelected) {
      emit(
        state.copyWith(
          list: state.list,
          counter: state.counter - 1,
        ),
      );
    } else {
      emit(
        state.copyWith(
          list: state.list,
          counter: state.counter + 1,
        ),
      );
    }
  }

  void listSelected(int pageId) {
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        repository.editMessage(
          state.list[i].copyWith(
            pageId: pageId,
            isSelected: false,
          ),
        );
      }
    }
    toInputAppBar();
  }

  void toEditAppBar() {
    var index = 0;
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        index = i;
        break;
      }
    }
    controller.text = state.list[index].text;
    emit(
      state.copyWith(
        enabledController: true,
        mode: Mode.edit,
        onAddMessage: ediTextMessage,
        indexCategory: state.list[index].indexCategory,
        attachedPhotoPath: state.list[index].photo,
      ),
    );
  }

  void ediTextMessage() {
    int index;
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        index = i;
        break;
      }
    }
    repository.editMessage(
      state.list[index].copyWith(
        text: controller.text,
        isSelected: false,
        indexCategory: state.indexCategory,
      ),
    );
    toInputAppBar();
    controller.text = '';
  }

  void copy() {
    var clipBoard = '';
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        clipBoard += state.list[i].text;
        selection(i);
      }
    }
    Clipboard.setData(ClipboardData(text: clipBoard));
  }

  void makeFavor() {
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        repository.editMessage(
          state.list[i].copyWith(
            isFavor: !state.list[i].isFavor,
            isSelected: false,
          ),
        );
        state.list[i] = state.list[i].copyWith(
          isFavor: !state.list[i].isFavor,
          isSelected: false,
        );
      }
    }
    toInputAppBar();
  }

  void delete(int index) {
    repository.removeMessage(state.list[index].id);
    state.list.removeAt(index);
    emit(
      state.copyWith(
        list: state.list,
      ),
    );
  }

  void deleteSelected() {
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        repository.removeMessage(state.list[i].id);
        state.list.removeAt(i);
      }
    }
    emit(
      state.copyWith(
        counter: 0,
        list: state.list,
      ),
    );
  }

  void remove(int id) {
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        repository.removeMessage(state.list[i].id);
      }
    }
  }

  void backToInputAppBar() {
    controller.text = '';
    for (var i = 0; i < state.list.length; i++) {
      if (state.list[i].isSelected) {
        selection(i);
      }
    }
    toInputAppBar();
  }

  void showCategoryList() {
    emit(
      state.copyWith(
        floatingBar: FloatingBar.category,
        onAddCategory: closeFloatingBar,
        onAddMessage: controller.text.isEmpty ? showPhotoOption : addMessage,
        isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
          if (index == 0) return true;
          return state.isStartAnim[index];
        }),
      ),
    );
  }

  void closeFloatingBar() {
    emit(
      state.copyWith(
        onAddCategory: showCategoryList,
        onAddMessage: controller.text.isEmpty ? showPhotoOption : addMessage,
        floatingBar: state.attachedPhotoPath.isEmpty
            ? FloatingBar.nothing
            : FloatingBar.attach,
        isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
          if (index == 3 && state.attachedPhotoPath.isNotEmpty) return true;
          return state.isStartAnim[index];
        }),
      ),
    );
  }

  void changeDisplay(int index) {
    emit(
      state.copyWith(
        isStartAnim: List<bool>.generate(state.isStartAnim.length, (i) {
          if (i == index) return false;
          return state.isStartAnim[i];
        }),
        attachedPhotoPath: state.floatingBar == FloatingBar.nothing
            ? ''
            : state.attachedPhotoPath,
      ),
    );
  }

  void cancelSelected() {
    emit(
      state.copyWith(
        floatingBar: state.attachedPhotoPath.isEmpty
            ? FloatingBar.nothing
            : FloatingBar.attach,
        onAddCategory: showCategoryList,
        indexCategory: -1,
        isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
          if (index == 3 && state.attachedPhotoPath.isNotEmpty) return true;
          return state.isStartAnim[index];
        }),
      ),
    );
  }

  void showPhotoOption() {
    emit(
      state.copyWith(
          floatingBar: FloatingBar.photosOption,
          onAddMessage: closeFloatingBar,
          onAddCategory: showCategoryList,
          isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
            if (index == 1) return true;
            return state.isStartAnim[index];
          })),
    );
  }

  void selectedCategory(int index) {
    emit(
      state.copyWith(
        floatingBar: state.attachedPhotoPath.isEmpty
            ? FloatingBar.nothing
            : FloatingBar.attach,
        onAddCategory: showCategoryList,
        indexCategory: index,
        iconDataPhoto: Icons.add,
        onAddMessage: state.mode == Mode.input ? addMessage : ediTextMessage,
        isStartAnim: List<bool>.generate(state.isStartAnim.length, (index) {
          if (index == 3 && state.attachedPhotoPath.isNotEmpty) return true;
          return state.isStartAnim[index];
        }),
      ),
    );
  }

  void updateDateAndTime({
    DateTime date,
    TimeOfDay time,
  }) {
    if (date != state.fromDate || time != state.fromTime) {
      emit(
        state.copyWith(
          fromDate: date,
          fromTime: time,
          isReset: true,
        ),
      );
    }
  }

  void reset() {
    final date = DateTime.now();
    emit(
      state.copyWith(
        fromDate: date,
        fromTime: TimeOfDay.fromDateTime(date),
        isReset: false,
      ),
    );
  }

  @override
  Future<Function> close() {
    controller.dispose();
    return super.close();
  }
}
