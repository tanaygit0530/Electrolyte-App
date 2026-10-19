const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

describe('Security & Input Sanitization Tests', () => {
  function escapeLikePattern(str) {
    if (!str || typeof str !== 'string') return '';
    return str.replace(/([%_\\])/g, '\\$1');
  }

  test('escapeLikePattern escapes %, _, and \\ characters', () => {
    assert.equal(escapeLikePattern('test%value'), 'test\\%value');
    assert.equal(escapeLikePattern('test_value'), 'test\\_value');
    assert.equal(escapeLikePattern('test\\value'), 'test\\\\value');
    assert.equal(escapeLikePattern('100%_guaranteed'), '100\\%\\_guaranteed');
    assert.equal(escapeLikePattern('normal-string'), 'normal-string');
    assert.equal(escapeLikePattern(''), '');
    assert.equal(escapeLikePattern(null), '');
  });
});

describe('Token & Lockout Validation Logic', () => {
  test('Account lockout threshold logic triggers after 5 failed attempts', () => {
    const MAX_FAILED_ATTEMPTS = 5;
    const LOCKOUT_DURATION_MS = 30 * 60 * 1000;

    let failedAttempts = 4;
    let isLocked = false;
    let lockedUntil = null;

    failedAttempts++;
    if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
      isLocked = true;
      lockedUntil = new Date(Date.now() + LOCKOUT_DURATION_MS);
    }

    assert.equal(failedAttempts, 5);
    assert.equal(isLocked, true);
    assert.ok(lockedUntil.getTime() > Date.now());
  });

  test('Active account check rejects deactivated user accounts', () => {
    const userActive = { id: 1, email: 'tech@test.com', is_active: true };
    const userDeactivated = { id: 2, email: 'inactive@test.com', is_active: false };

    function checkActiveStatus(user) {
      if (!user || user.is_active === false) {
        throw new Error('User account is deactivated. Contact administrator.');
      }
      return true;
    }

    assert.equal(checkActiveStatus(userActive), true);
    assert.throws(() => checkActiveStatus(userDeactivated), {
      message: 'User account is deactivated. Contact administrator.'
    });
  });
});

describe('60-Day Warranty Rule Verification', () => {
  test('Calculates whether a service record is within 60 days', () => {
    function isWithin60Days(recordDate) {
      const now = new Date();
      const past60Days = new Date(now.getTime() - (60 * 24 * 60 * 60 * 1000));
      return recordDate >= past60Days && recordDate <= now;
    }

    const today = new Date();
    const tenDaysAgo = new Date(Date.now() - (10 * 24 * 60 * 60 * 1000));
    const fiftyNineDaysAgo = new Date(Date.now() - (59 * 24 * 60 * 60 * 1000));
    const sixtyOneDaysAgo = new Date(Date.now() - (61 * 24 * 60 * 60 * 1000));

    assert.equal(isWithin60Days(today), true);
    assert.equal(isWithin60Days(tenDaysAgo), true);
    assert.equal(isWithin60Days(fiftyNineDaysAgo), true);
    assert.equal(isWithin60Days(sixtyOneDaysAgo), false);
  });
});
