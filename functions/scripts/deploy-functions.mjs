#!/usr/bin/env node
import {spawn} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

export const PRODUCTION_PROJECT_ID = 'project0000-ec01e';

export function testDeploymentProject(args) {
  let project;
  for (let index = 0; index < args.length; index++) {
    const value = args[index];
    if (value === '--project') project = args[++index];
    else if (value.startsWith('--project=')) project = value.slice('--project='.length);
    else throw new Error(`Unsupported deployment argument: ${value}`);
  }
  if (!project) {
    throw new Error('A test Firebase project is required: --project=<test-project-id>');
  }
  if (project === PRODUCTION_PROJECT_ID || project === 'default') {
    throw new Error('This command refuses the production Firebase project. Test the full candidate first.');
  }
  return project;
}

export async function deployTestFunctions(args = process.argv.slice(2)) {
  const project = testDeploymentProject(args);
  const firebaseBinary = resolve(
    'node_modules',
    '.bin',
    process.platform === 'win32' ? 'firebase.cmd' : 'firebase',
  );
  const config = resolve('..', 'firebase.test.json');
  const child = spawn(
    firebaseBinary,
    ['deploy', '--config', config, '--only', 'functions', '--project', project],
    {stdio: 'inherit'},
  );
  return await new Promise((resolveResult, reject) => {
    child.once('error', reject);
    child.once('exit', (code, signal) => {
      if (signal) reject(new Error(`Firebase CLI terminated by ${signal}`));
      else resolveResult(code ?? 1);
    });
  });
}

const invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : null;
if (invokedPath === import.meta.url) {
  deployTestFunctions()
    .then(code => {
      process.exitCode = code;
    })
    .catch(error => {
      console.error(error instanceof Error ? error.message : String(error));
      process.exitCode = 2;
    });
}
