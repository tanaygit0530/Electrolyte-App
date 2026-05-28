const { pool } = require('../config/neondb');

const checkLocks = async () => {
  try {
    console.log('Checking database locks and blocking activities...');
    
    // Check for blocked queries
    const blockedRes = await pool.query(`
      SELECT 
        blocked_locks.pid AS blocked_pid,
        blocked_activity.usename AS blocked_user,
        blocking_locks.pid AS blocking_pid,
        blocking_activity.usename AS blocking_user,
        blocked_activity.query AS blocked_statement,
        blocking_activity.query AS current_statement_in_blocking_process
      FROM  pg_catalog.pg_locks         blocked_locks
      JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
      JOIN pg_catalog.pg_locks         blocking_locks 
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid
      JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
      WHERE NOT blocked_locks.granted;
    `);

    console.log(`Found ${blockedRes.rows.length} blocked processes.`);
    blockedRes.rows.forEach((row, i) => {
      console.log(`[Block #${i+1}]`);
      console.log(` - Blocked PID: ${row.blocked_pid} (${row.blocked_user})`);
      console.log(` - Blocked Statement: ${row.blocked_statement}`);
      console.log(` - Blocking PID: ${row.blocking_pid} (${row.blocking_user})`);
      console.log(` - Blocking Statement: ${row.current_statement_in_blocking_process}`);
    });

    // Check all active connections
    const activeRes = await pool.query(`
      SELECT pid, state, query, age(clock_timestamp(), query_start) AS duration
      FROM pg_stat_activity 
      WHERE state IS NOT DISTINCT FROM 'active' AND query NOT LIKE '%stat_activity%';
    `);
    
    console.log(`\nActive processes: ${activeRes.rows.length}`);
    activeRes.rows.forEach(row => {
      console.log(` - PID: ${row.pid}, Duration: ${row.duration}, State: ${row.state}, Query: ${row.query}`);
    });

  } catch (err) {
    console.error('Error checking locks:', err.message);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

checkLocks();
