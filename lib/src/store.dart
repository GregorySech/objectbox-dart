import "dart:ffi";

import "bindings/bindings.dart";
import "bindings/helpers.dart";
import "modelinfo/index.dart";

import "model.dart";

import "package:ffi/ffi.dart";

enum TxMode {
  Read,
  Write,
}

class Store {
  Pointer<Void> _cStore;
  Map<Type, EntityDefinition> _entityDefinitions = {};

  Store._(this._entityDefinitions, Model model, {String directory, int maxDBSizeInKB, int fileMode, int maxReaders}) {
    var opt = bindings.obx_opt();
    checkObxPtr(opt, "failed to create store options");

    try {
      checkObx(bindings.obx_opt_model(opt, model.ptr));
      if (directory != null && directory.length != 0) {
        var cStr = Utf8.toUtf8(directory).cast<Uint8>();
        try {
          checkObx(bindings.obx_opt_directory(opt, cStr));
        } finally {
          cStr.free();
        }
      }
      if (maxDBSizeInKB != null && maxDBSizeInKB > 0) bindings.obx_opt_max_db_size_in_kb(opt, maxDBSizeInKB);
      if (fileMode != null && fileMode >= 0) bindings.obx_opt_file_mode(opt, fileMode);
      if (maxReaders != null && maxReaders > 0) bindings.obx_opt_max_readers(opt, maxReaders);
    } catch (e) {
      bindings.obx_opt_free(opt);
      rethrow;
    }
    _cStore = bindings.obx_store_open(opt);
    checkObxPtr(_cStore, "failed to create store");
  }

  static Future<Store> create(List<EntityDefinition> defs,
      {String directory, int maxDBSizeInKB, int fileMode, int maxReaders}) async {
    Map<Type, EntityDefinition> entityDefinitions = {};
    defs.forEach((d) => entityDefinitions[d.type()] = d);

    List<ModelEntity> modelEntities = [];
    for (EntityDefinition d in defs) modelEntities.add(await d.getModel());
    var model = Model(modelEntities);

    return Store._(entityDefinitions, model,
        directory: directory, maxDBSizeInKB: maxDBSizeInKB, fileMode: fileMode, maxReaders: maxReaders);
  }

  close() {
    checkObx(bindings.obx_store_close(_cStore));
  }

  EntityDefinition<T> entityDef<T>(T) {
    return _entityDefinitions[T];
  }

  /// Executes a given function inside a transaction
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    assert(mode == TxMode.Read, "write transactions are currently not supported"); // TODO implement

    Pointer<Void> txn = bindings.obx_txn_read(_cStore);
    checkObxPtr(txn, "failed to created transaction");
    try {
      return fn();
    } finally {
      checkObx(bindings.obx_txn_close(txn));
    }
  }

  get ptr => _cStore;
}
