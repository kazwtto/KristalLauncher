package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.model.LoveGame
import org.json.JSONArray

object FavoritesManager {

    private const val PREFS_NAME = "kristal_favorites_prefs"
    private const val KEY_FAVORITES = "favorite_games_set"
    private const val KEY_RECENTS = "recent_games_list"
    private const val KEY_RECENTS_JSON = "recent_game_ids_json"

    fun isFavorite(context: Context, game: LoveGame): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val favorites = prefs.getStringSet(KEY_FAVORITES, emptySet()) ?: emptySet()
        if (game.stableId in favorites) return true
        if (game.fileName !in favorites) return false

        val migrated = favorites.toMutableSet().apply {
            remove(game.fileName)
            add(game.stableId)
        }
        prefs.edit().putStringSet(KEY_FAVORITES, migrated).apply()
        return true
    }

    fun toggleFavorite(context: Context, game: LoveGame): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val favorites = (prefs.getStringSet(KEY_FAVORITES, emptySet()) ?: emptySet()).toMutableSet()
        favorites.remove(game.fileName)
        val newState = if (favorites.contains(game.stableId)) {
            favorites.remove(game.stableId)
            false
        } else {
            favorites.add(game.stableId)
            true
        }
        prefs.edit().putStringSet(KEY_FAVORITES, favorites).apply()
        return newState
    }

    fun getFavoriteGameIds(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_FAVORITES, emptySet()) ?: emptySet()
    }

    fun addRecentGame(context: Context, game: LoveGame) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val recentsList = readRecentIds(context).toMutableList()

        recentsList.remove(game.fileName)
        recentsList.remove(game.stableId)
        recentsList.add(0, game.stableId)

        if (recentsList.size > 20) {
            recentsList.removeAt(recentsList.size - 1)
        }

        prefs.edit()
            .putString(KEY_RECENTS_JSON, JSONArray(recentsList).toString())
            .remove(KEY_RECENTS)
            .apply()
    }

    fun getRecentGameIds(context: Context): List<String> = readRecentIds(context)

    private fun readRecentIds(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_RECENTS_JSON, null)
        if (!json.isNullOrBlank()) {
            return runCatching {
                val array = JSONArray(json)
                buildList {
                    for (index in 0 until array.length()) {
                        array.optString(index).takeIf(String::isNotBlank)?.let(::add)
                    }
                }
            }.getOrDefault(emptyList())
        }

        val recentsStr = prefs.getString(KEY_RECENTS, "") ?: ""
        if (recentsStr.isEmpty()) return emptyList()
        return recentsStr.split(",")
    }
}
