# Log Header
SELECT " ";
SELECT NOW() as "=== Optimierung MySQL DB maya: START ===";

# sessions: delete sessions that have not been used
DELETE FROM sessions WHERE TIMESTAMPDIFF(SECOND, created_at, updated_at) < 2;
# sessions: delete sessions not used in the last 7 days
DELETE FROM sessions WHERE updated_at < (NOW()-INTERVAL 7 DAY);
# search_logs: delete log entries without search query and facet selection
DELETE FROM search_logs WHERE search_logs.query = '' AND search_logs.facet_filter = '{}';
# Statistics
SELECT "Sessions" AS "--- Table ---", count(*) AS "--- Anzahl ---" FROM sessions UNION SELECT "Search Logs" AS "--- Table ---", count(*) AS "--- Anzahl ---" FROM search_logs;

# Log Footer
SELECT NOW() as "=== Optimierung MySQL DB maya: END ===";
