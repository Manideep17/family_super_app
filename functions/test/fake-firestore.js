"use strict";
// Minimal in-memory Firestore stand-in covering exactly the surface used by
// account.ts / weekly.ts / join_codes.ts, so we can execute the REAL compiled
// Cloud Functions handlers with zero network access (no emulator, no real
// GCP project) and assert on real before/after state.

const SERVER_TS = Symbol("serverTimestamp");
const INCREMENT = Symbol("increment");

/** Minimal stand-in for `admin.firestore.Timestamp` — real class instance
 * (not a plain Date) so `instanceof admin.firestore.Timestamp` checks in
 * real handler code (e.g. referrals.ts) work correctly against it. */
class FakeTimestamp {
  constructor(millis) {
    this._millis = millis;
  }
  toMillis() {
    return this._millis;
  }
  toDate() {
    return new Date(this._millis);
  }
  static fromDate(d) {
    return new FakeTimestamp(d.getTime());
  }
  static fromMillis(ms) {
    return new FakeTimestamp(ms);
  }
  static now() {
    return new FakeTimestamp(Date.now());
  }
}

function isPlainObject(v) {
  return (
    v &&
    typeof v === "object" &&
    !(v instanceof Date) &&
    !(v instanceof FakeTimestamp) &&
    !Array.isArray(v)
  );
}

function resolveWrite(data, existing) {
  const base = existing && typeof existing === "object" ? existing : {};
  const out = Array.isArray(data) ? [] : {};
  for (const [k, v] of Object.entries(data)) {
    if (v === SERVER_TS) out[k] = new FakeTimestamp(Date.now());
    else if (v && typeof v === "object" && v[INCREMENT] !== undefined) {
      const prev = typeof base[k] === "number" ? base[k] : 0;
      out[k] = prev + v[INCREMENT];
    } else if (isPlainObject(v)) out[k] = resolveWrite(v, base[k]);
    else out[k] = v;
  }
  return out;
}

class FakeDb {
  constructor() {
    this.store = new Map(); // full path -> data object
    this.poisonPaths = new Set(); // collection paths that throw on get()
  }
  collection(path) {
    return new FakeCollectionRef(this, path);
  }
  batch() {
    const ops = [];
    const self = this;
    return {
      set(ref, data, opts) {
        ops.push({ type: "set", path: ref.path, data, opts });
      },
      update(ref, data) {
        ops.push({ type: "update", path: ref.path, data });
      },
      delete(ref) {
        ops.push({ type: "delete", path: ref.path });
      },
      async commit() {
        for (const op of ops) {
          if (op.type === "set") self._setDoc(op.path, op.data, op.opts);
          else if (op.type === "update") self._updateDoc(op.path, op.data);
          else if (op.type === "delete") self.store.delete(op.path);
        }
      },
    };
  }
  _setDoc(path, data, opts) {
    const existing = this.store.get(path) || {};
    const resolved = resolveWrite(data, existing);
    if (opts && opts.merge) {
      this.store.set(path, { ...existing, ...resolved });
    } else {
      this.store.set(path, resolved);
    }
  }
  _updateDoc(path, data) {
    if (!this.store.has(path)) {
      throw new Error(`FakeFirestore: update() on missing doc ${path}`);
    }
    const existing = this.store.get(path);
    const resolved = resolveWrite(data, existing);
    this.store.set(path, { ...existing, ...resolved });
  }
  async runTransaction(updateFunction) {
    // Simplified: no isolation/snapshot consistency or automatic retry on
    // contention — this fake is single-threaded and only needs to prove
    // the handler's decision logic (read-then-write shape), not real
    // transaction semantics.
    const self = this;
    const tx = {
      get: (ref) => ref.get(),
      set: (ref, data, opts) => self._setDoc(ref.path, data, opts),
      update: (ref, data) => self._updateDoc(ref.path, data),
      delete: (ref) => self.store.delete(ref.path),
    };
    return updateFunction(tx);
  }
}

class FakeDocRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").pop();
  }
  collection(sub) {
    return new FakeCollectionRef(this.db, `${this.path}/${sub}`);
  }
  async get() {
    const data = this.db.store.get(this.path);
    const ref = this;
    return {
      exists: data !== undefined,
      id: this.id,
      ref,
      data: () => data,
      get: (field) => (data ? data[field] : undefined),
    };
  }
  async set(data, opts) {
    this.db._setDoc(this.path, data, opts);
  }
  async update(data) {
    this.db._updateDoc(this.path, data);
  }
  async delete() {
    this.db.store.delete(this.path);
  }
}

class FakeCollectionRef {
  constructor(db, path, filters = [], order = null, limitN = null) {
    this.db = db;
    this.path = path;
    this._filters = filters;
    this._order = order;
    this._limit = limitN;
  }
  doc(id) {
    return new FakeDocRef(this.db, `${this.path}/${id}`);
  }
  where(field, op, value) {
    return new FakeCollectionRef(
      this.db,
      this.path,
      [...this._filters, { field, op, value }],
      this._order,
      this._limit,
    );
  }
  orderBy(field, direction = "asc") {
    return new FakeCollectionRef(this.db, this.path, this._filters, { field, direction }, this._limit);
  }
  limit(n) {
    return new FakeCollectionRef(this.db, this.path, this._filters, this._order, n);
  }
  async get() {
    if (this.db.poisonPaths.has(this.path)) {
      throw new Error(`FakeFirestore: simulated failure reading ${this.path}`);
    }
    const prefix = this.path + "/";
    const depth = this.path.split("/").length + 1;
    let docs = [];
    for (const [path, data] of this.db.store.entries()) {
      if (!path.startsWith(prefix)) continue;
      if (path.split("/").length !== depth) continue; // direct children only
      let ok = true;
      for (const f of this._filters) {
        const v = data ? data[f.field] : undefined;
        if (f.op === "==" && v !== f.value) ok = false;
        else if (f.op === ">=" && !(v >= f.value)) ok = false;
        else if (f.op === "<=" && !(v <= f.value)) ok = false;
      }
      if (ok) docs.push({ path, data, id: path.split("/").pop() });
    }
    if (this._order) {
      const { field, direction } = this._order;
      docs.sort((a, b) => {
        const av = a.data ? a.data[field] : undefined;
        const bv = b.data ? b.data[field] : undefined;
        const at = av instanceof Date ? av.getTime() : av;
        const bt = bv instanceof Date ? bv.getTime() : bv;
        return direction === "desc" ? bt - at : at - bt;
      });
    }
    if (this._limit != null) docs = docs.slice(0, this._limit);
    return {
      empty: docs.length === 0,
      size: docs.length,
      docs: docs.map((d) => ({
        id: d.id,
        ref: new FakeDocRef(this.db, d.path),
        data: () => d.data,
        get: (field) => (d.data ? d.data[field] : undefined),
      })),
    };
  }
}

function overrideProp(obj, key, value) {
  Object.defineProperty(obj, key, {
    value,
    writable: true,
    configurable: true,
    enumerable: true,
  });
}

function installFakeAdmin(admin) {
  const db = new FakeDb();
  const firestoreFn = () => db;
  firestoreFn.FieldValue = {
    serverTimestamp: () => SERVER_TS,
    delete: () => undefined,
    increment: (n) => ({ [INCREMENT]: n }),
  };
  firestoreFn.Timestamp = FakeTimestamp;
  overrideProp(admin, "firestore", firestoreFn);
  overrideProp(admin, "initializeApp", () => ({}));
  const deletedAuthUsers = [];
  overrideProp(admin, "auth", () => ({
    deleteUser: async (uid) => {
      deletedAuthUsers.push(uid);
    },
  }));
  overrideProp(admin, "messaging", () => ({
    sendEachForMulticast: async () => ({ responses: [] }),
  }));
  return { db, deletedAuthUsers };
}

module.exports = { installFakeAdmin, FakeDb };
