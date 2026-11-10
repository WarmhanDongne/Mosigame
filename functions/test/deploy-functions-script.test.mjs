import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import {
  PRODUCTION_PROJECT_ID,
  testDeploymentProject,
} from '../scripts/deploy-functions.mjs';

test('test Functions deploy requires an explicit non-production project', () => {
  assert.equal(
    testDeploymentProject(['--project=mosigame-network-test']),
    'mosigame-network-test',
  );
  assert.equal(
    testDeploymentProject(['--project', 'mosigame-network-test']),
    'mosigame-network-test',
  );
  assert.throws(() => testDeploymentProject([]), /test Firebase project is required/);
  assert.throws(
    () => testDeploymentProject([`--project=${PRODUCTION_PROJECT_ID}`]),
    /refuses the production Firebase project/,
  );
  assert.throws(
    () => testDeploymentProject(['--project=default']),
    /refuses the production Firebase project/,
  );
});

test('test Functions deploy rejects arguments that could widen deployment scope', () => {
  assert.throws(
    () => testDeploymentProject(['--project=mosigame-network-test', '--only', 'functions']),
    /Unsupported deployment argument/,
  );
});

test('test Firebase config isolates Mosigame from the existing default codebase', () => {
  const config = JSON.parse(readFileSync('../firebase.test.json', 'utf8'));
  assert.equal(config.functions[0].codebase, 'mosigame-test');
  assert.equal(config.database.rules, 'database.rules.json');
  assert.equal(config.firestore.rules, 'firestore.rules');
  assert.equal(config.storage.rules, 'storage.rules');
});
