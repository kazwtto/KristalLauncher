package kwz.love2d.launcher.util

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import kwz.love2d.launcher.model.TranslationEntry
import kwz.love2d.launcher.model.TranslationProject

internal class TranslationDatabase private constructor(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                author TEXT NOT NULL DEFAULT '',
                game_stable_id TEXT NOT NULL,
                game_project_id TEXT,
                game_title TEXT NOT NULL,
                game_version TEXT,
                source_fingerprint TEXT NOT NULL,
                source_root TEXT NOT NULL,
                target_root TEXT NOT NULL,
                source_language TEXT NOT NULL,
                target_language TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE entries (
                project_id TEXT NOT NULL,
                entry_id TEXT NOT NULL,
                source_text TEXT NOT NULL,
                translated_text TEXT NOT NULL DEFAULT '',
                file_path TEXT NOT NULL,
                file_hash TEXT NOT NULL,
                start_offset INTEGER NOT NULL,
                end_offset INTEGER NOT NULL,
                line_number INTEGER NOT NULL,
                kind TEXT NOT NULL,
                context TEXT NOT NULL,
                PRIMARY KEY(project_id, entry_id),
                FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX entries_project_file ON entries(project_id, file_path)")
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE projects ADD COLUMN name TEXT NOT NULL DEFAULT ''")
            db.execSQL("ALTER TABLE projects ADD COLUMN author TEXT NOT NULL DEFAULT ''")
            db.execSQL("UPDATE projects SET name = game_title || ' translation' WHERE name = ''")
        }
    }

    fun insertProject(project: TranslationProject, entries: List<TranslationEntry>) {
        writableDatabase.beginTransaction()
        try {
            writableDatabase.insertOrThrow("projects", null, projectValues(project))
            entries.forEach { entry ->
                writableDatabase.insertOrThrow("entries", null, entryValues(entry.copy(projectId = project.id)))
            }
            writableDatabase.setTransactionSuccessful()
        } finally {
            writableDatabase.endTransaction()
        }
    }

    fun projectsForGame(gameStableId: String): List<TranslationProject> {
        val sql = """
            SELECT p.*,
                COUNT(e.entry_id) AS total_entries,
                SUM(CASE WHEN e.translated_text <> '' THEN 1 ELSE 0 END) AS translated_entries
            FROM projects p
            LEFT JOIN entries e ON e.project_id = p.id
            WHERE p.game_stable_id = ?
            GROUP BY p.id
            ORDER BY p.updated_at DESC
        """.trimIndent()
        return readableDatabase.rawQuery(sql, arrayOf(gameStableId)).use { cursor ->
            buildList {
                while (cursor.moveToNext()) add(projectFromCursor(cursor))
            }
        }
    }

    fun project(projectId: String): TranslationProject? {
        val sql = """
            SELECT p.*,
                COUNT(e.entry_id) AS total_entries,
                SUM(CASE WHEN e.translated_text <> '' THEN 1 ELSE 0 END) AS translated_entries
            FROM projects p
            LEFT JOIN entries e ON e.project_id = p.id
            WHERE p.id = ?
            GROUP BY p.id
        """.trimIndent()
        return readableDatabase.rawQuery(sql, arrayOf(projectId)).use { cursor ->
            if (cursor.moveToFirst()) projectFromCursor(cursor) else null
        }
    }

    fun entries(projectId: String): List<TranslationEntry> {
        return readableDatabase.query(
            "entries", null, "project_id = ?", arrayOf(projectId), null, null,
            "CASE WHEN translated_text = '' THEN 0 ELSE 1 END, file_path, line_number"
        ).use { cursor ->
            buildList { while (cursor.moveToNext()) add(entryFromCursor(cursor)) }
        }
    }

    fun entry(projectId: String, entryId: String): TranslationEntry? {
        return readableDatabase.query(
            "entries", null, "project_id = ? AND entry_id = ?",
            arrayOf(projectId, entryId), null, null, null, "1"
        ).use { cursor -> if (cursor.moveToFirst()) entryFromCursor(cursor) else null }
    }

    fun updateTranslation(projectId: String, entryId: String, value: String) {
        writableDatabase.beginTransaction()
        try {
            writableDatabase.update(
                "entries",
                ContentValues().apply { put("translated_text", value) },
                "project_id = ? AND entry_id = ?",
                arrayOf(projectId, entryId)
            )
            writableDatabase.update(
                "projects",
                ContentValues().apply { put("updated_at", System.currentTimeMillis()) },
                "id = ?",
                arrayOf(projectId)
            )
            writableDatabase.setTransactionSuccessful()
        } finally {
            writableDatabase.endTransaction()
        }
    }

    fun updateProject(projectId: String, name: String, author: String, targetLanguage: String) {
        writableDatabase.update(
            "projects",
            ContentValues().apply {
                put("name", name)
                put("author", author)
                put("target_language", targetLanguage)
                put("updated_at", System.currentTimeMillis())
            },
            "id = ?",
            arrayOf(projectId)
        )
    }

    fun clearTranslations(projectId: String) {
        writableDatabase.beginTransaction()
        try {
            writableDatabase.update(
                "entries",
                ContentValues().apply { put("translated_text", "") },
                "project_id = ?",
                arrayOf(projectId)
            )
            writableDatabase.update(
                "projects",
                ContentValues().apply { put("updated_at", System.currentTimeMillis()) },
                "id = ?",
                arrayOf(projectId)
            )
            writableDatabase.setTransactionSuccessful()
        } finally {
            writableDatabase.endTransaction()
        }
    }

    fun updateTranslations(projectId: String, translations: Map<String, String>) {
        writableDatabase.beginTransaction()
        try {
            translations.forEach { (entryId, value) ->
                writableDatabase.update(
                    "entries",
                    ContentValues().apply { put("translated_text", value) },
                    "project_id = ? AND entry_id = ?",
                    arrayOf(projectId, entryId)
                )
            }
            writableDatabase.update(
                "projects",
                ContentValues().apply { put("updated_at", System.currentTimeMillis()) },
                "id = ?",
                arrayOf(projectId)
            )
            writableDatabase.setTransactionSuccessful()
        } finally {
            writableDatabase.endTransaction()
        }
    }

    fun deleteProject(projectId: String) {
        writableDatabase.delete("projects", "id = ?", arrayOf(projectId))
    }

    private fun projectValues(project: TranslationProject) = ContentValues().apply {
        put("id", project.id)
        put("name", project.name)
        put("author", project.author)
        put("game_stable_id", project.gameStableId)
        put("game_project_id", project.gameProjectId)
        put("game_title", project.gameTitle)
        put("game_version", project.gameVersion)
        put("source_fingerprint", project.sourceFingerprint)
        put("source_root", project.sourceRoot)
        put("target_root", project.targetRoot)
        put("source_language", project.sourceLanguage)
        put("target_language", project.targetLanguage)
        put("created_at", project.createdAt)
        put("updated_at", project.updatedAt)
    }

    private fun entryValues(entry: TranslationEntry) = ContentValues().apply {
        put("project_id", entry.projectId)
        put("entry_id", entry.id)
        put("source_text", entry.sourceText)
        put("translated_text", entry.translatedText)
        put("file_path", entry.filePath)
        put("file_hash", entry.fileHash)
        put("start_offset", entry.startOffset)
        put("end_offset", entry.endOffset)
        put("line_number", entry.line)
        put("kind", entry.kind)
        put("context", entry.context)
    }

    private fun projectFromCursor(cursor: android.database.Cursor) = TranslationProject(
        id = cursor.string("id"),
        name = cursor.string("name"),
        author = cursor.string("author"),
        gameStableId = cursor.string("game_stable_id"),
        gameProjectId = cursor.nullableString("game_project_id"),
        gameTitle = cursor.string("game_title"),
        gameVersion = cursor.nullableString("game_version"),
        sourceFingerprint = cursor.string("source_fingerprint"),
        sourceRoot = cursor.string("source_root"),
        targetRoot = cursor.string("target_root"),
        sourceLanguage = cursor.string("source_language"),
        targetLanguage = cursor.string("target_language"),
        createdAt = cursor.long("created_at"),
        updatedAt = cursor.long("updated_at"),
        totalEntries = cursor.int("total_entries"),
        translatedEntries = cursor.int("translated_entries")
    )

    private fun entryFromCursor(cursor: android.database.Cursor) = TranslationEntry(
        projectId = cursor.string("project_id"),
        id = cursor.string("entry_id"),
        sourceText = cursor.string("source_text"),
        translatedText = cursor.string("translated_text"),
        filePath = cursor.string("file_path"),
        fileHash = cursor.string("file_hash"),
        startOffset = cursor.int("start_offset"),
        endOffset = cursor.int("end_offset"),
        line = cursor.int("line_number"),
        kind = cursor.string("kind"),
        context = cursor.string("context")
    )

    private fun android.database.Cursor.string(name: String) = getString(getColumnIndexOrThrow(name))
    private fun android.database.Cursor.nullableString(name: String) =
        getColumnIndexOrThrow(name).let { if (isNull(it)) null else getString(it) }
    private fun android.database.Cursor.int(name: String) = getInt(getColumnIndexOrThrow(name))
    private fun android.database.Cursor.long(name: String) = getLong(getColumnIndexOrThrow(name))

    companion object {
        private const val DATABASE_NAME = "community_translations.db"
        private const val DATABASE_VERSION = 2

        @Volatile private var instance: TranslationDatabase? = null

        fun get(context: Context): TranslationDatabase = instance ?: synchronized(this) {
            instance ?: TranslationDatabase(context.applicationContext).also { instance = it }
        }
    }
}
