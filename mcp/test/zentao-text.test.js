import { test } from 'node:test';
import assert from 'node:assert/strict';
import { messageText } from '../src/zentao.js';

test('renders ZenTao mentions as @Name', () => {
  assert.equal(messageText({ contentType: 'plain', content: '[@Victor (98)](@#34) [@Long](@#26) ok' }), '@Victor (98) @Long ok');
});
