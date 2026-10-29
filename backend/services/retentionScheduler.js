const { cleanupExpiredServiceRecords } = require('../controllers/serviceRecordsController');

let schedulerTimer = null;
let intervalTimer = null;

/**
 * Calculate delay in milliseconds until next target time in Asia/Kolkata timezone.
 * Defaults to 00:05 AM IST.
 */
function getMsUntilNextISTTime(targetHour = 0, targetMinute = 5) {
  const now = new Date();
  
  // Format current time in Asia/Kolkata
  const istFormatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hour12: false
  });
  
  const parts = istFormatter.formatToParts(now);
  const partMap = {};
  for (const p of parts) partMap[p.type] = p.value;

  const curYear = parseInt(partMap.year, 10);
  const curMonth = parseInt(partMap.month, 10) - 1;
  const curDay = parseInt(partMap.day, 10);
  const curHour = parseInt(partMap.hour, 10);
  const curMinute = parseInt(partMap.minute, 10);
  const curSecond = parseInt(partMap.second, 10);

  // Target IST date
  let targetYear = curYear;
  let targetMonth = curMonth;
  let targetDay = curDay;

  // If already past target time today, schedule for tomorrow
  if (curHour > targetHour || (curHour === targetHour && curMinute >= targetMinute)) {
    targetDay += 1;
  }

  // Construct target timestamp (IST is UTC+5:30)
  const targetUtcMs = Date.UTC(targetYear, targetMonth, targetDay, targetHour - 5, targetMinute - 30, 0);
  const diffMs = Math.max(1000, targetUtcMs - now.getTime());
  return diffMs;
}

/**
 * Initialize automated daily retention scheduler for rolling 60-day service records.
 */
function initRetentionScheduler() {
  console.log('[Retention Scheduler] Initializing automated 60-day cleanup scheduler...');

  const executeCleanup = async () => {
    try {
      console.log('[Retention Scheduler] Executing scheduled 60-day data retention cleanup...');
      const result = await cleanupExpiredServiceRecords();
      if (result.skipped) {
        console.log(`[Retention Scheduler] Cleanup skipped: ${result.reason}`);
      } else {
        console.log(`[Retention Scheduler] Scheduled cleanup completed. Purged: ${result.deletedCount}, Remaining: ${result.remainingCount}`);
      }
    } catch (err) {
      console.error('[Retention Scheduler] Error during scheduled cleanup execution:', err.message || err);
    }
  };

  // 1. Initial startup check after 10 seconds of server boot
  setTimeout(async () => {
    try {
      await executeCleanup();
    } catch (_) {}
  }, 10000);

  // 2. Schedule daily recurring execution at 00:05 AM IST
  const scheduleNextDailyRun = () => {
    const delayMs = getMsUntilNextISTTime(0, 5);
    const delayHours = (delayMs / (1000 * 60 * 60)).toFixed(2);
    console.log(`[Retention Scheduler] Next daily cleanup scheduled in ${delayHours} hours (00:05 AM Asia/Kolkata).`);

    schedulerTimer = setTimeout(async () => {
      await executeCleanup();
      // Repeat daily (24 hours)
      intervalTimer = setInterval(executeCleanup, 24 * 60 * 60 * 1000);
    }, delayMs);
  };

  scheduleNextDailyRun();
}

function stopRetentionScheduler() {
  if (schedulerTimer) clearTimeout(schedulerTimer);
  if (intervalTimer) clearInterval(intervalTimer);
  console.log('[Retention Scheduler] Stopped.');
}

module.exports = {
  initRetentionScheduler,
  stopRetentionScheduler,
  getMsUntilNextISTTime
};
