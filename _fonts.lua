function importBotFonts()
  if not modules.game_bot or not modules.game_bot.contentsPanel or not modules.game_bot.contentsPanel.config then
    return false
  end

  local current = modules.game_bot.contentsPanel.config:getCurrentOption()
  if not current or not current.text or current.text == "" then
    return false
  end

  local cfg = current.text
  local base = "/bot/" .. cfg .. "/fonts/"

  modules._G.g_fonts.importFont(base .. "my-font/my-font.otfont")
  modules._G.g_fonts.importFont(base .. "roboto/roboto.otfont")
  modules._G.g_fonts.importFont(base .. "ava/ava.otfont")
  modules._G.g_fonts.importFont(base .. "lucida-11px-rounded/lucida-11px-rounded.otfont")
  modules._G.g_fonts.importFont(base .. "montserrat_bold_14/Montserrat_bold_14.otfont")
  modules._G.g_fonts.importFont(base .. "roboto-14/roboto-14.otfont")
  modules._G.g_fonts.importFont(base .. "sono_bold_border/sono_bold_border_14.otfont")

  return true
end

function tryImportBotFonts()
  if not importBotFonts() then
    scheduleEvent(tryImportBotFonts, 10)
  end
end

tryImportBotFonts()
tryImportBotFonts()
tryImportBotFonts()
tryImportBotFonts()
tryImportBotFonts()