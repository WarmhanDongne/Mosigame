import assert from 'node:assert/strict';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const firestore = require('firebase-admin/firestore');

export function mockPlatformMaintenanceInactive(t) {
  t.mock.method(firestore, 'getFirestore', () => ({
    collection(name) {
      assert.equal(name, 'platformAnnouncements');
      return {
        doc(id) {
          assert.equal(id, 'maintenance');
          return {get: async () => ({data: () => ({active: false})})};
        },
      };
    },
  }));
}
