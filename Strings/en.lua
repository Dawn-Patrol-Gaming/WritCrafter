-- English strings. Other languages override these with SafeAddString in their own file.

-- Settings: general
ZO_CreateStringId("SI_WRITCRAFTER_HEADER_GENERAL",             "General")
ZO_CreateStringId("SI_WRITCRAFTER_SAVED_FOR",                 "Server: <<1>>   Account: <<2>>   Character: <<3>>")
ZO_CreateStringId("SI_WRITCRAFTER_SCOPE",                      "Settings apply to")
ZO_CreateStringId("SI_WRITCRAFTER_SCOPE_TOOLTIP",              "Settings are saved separately for each server and account. \"All my characters on this server\" shares one set of settings. \"This character only\" gives this character its own, starting from a copy of the shared ones.")
ZO_CreateStringId("SI_WRITCRAFTER_SCOPE_SERVER",               "All my characters on this server")
ZO_CreateStringId("SI_WRITCRAFTER_SCOPE_CHARACTER",            "This character only")
ZO_CreateStringId("SI_WRITCRAFTER_RESPECT_LOCKS",              "Leave locked gear alone")
ZO_CreateStringId("SI_WRITCRAFTER_RESPECT_LOCKS_TOOLTIP",      "Never hand in, deconstruct, junk or destroy gear you've locked. Only equippable gear can be locked; materials, potions, poisons, food and glyphs can't. Items marked with FCO ItemSaver are also left alone.")
ZO_CreateStringId("SI_WRITCRAFTER_PRICE_SOURCE",               "Price source")
ZO_CreateStringId("SI_WRITCRAFTER_PRICE_SOURCE_TOOLTIP",       "Where item prices come from. Automatic tries ESO-Hub first, then Master Merchant, Arkadius Trade Tools and Tamriel Trade Centre.")
ZO_CreateStringId("SI_WRITCRAFTER_LOG_LEVEL",                  "Chat messages")
ZO_CreateStringId("SI_WRITCRAFTER_LOG_LEVEL_TOOLTIP",          "How much WritCrafter writes to chat. Full detail always goes to LibDebugLogger when it's installed.")

-- Settings: diagnostics
ZO_CreateStringId("SI_WRITCRAFTER_HEADER_DIAGNOSTICS",         "Diagnostics")
ZO_CreateStringId("SI_WRITCRAFTER_DIAGNOSTICS_TEXT",           "Type /wc stock or /wc price followed by an item link (shift-click an item into chat) to see what WritCrafter counts and prices.")

-- Choices
ZO_CreateStringId("SI_WRITCRAFTER_SOURCE_AUTO",                "Automatic")
ZO_CreateStringId("SI_WRITCRAFTER_SOURCE_ESOHUB",              "ESO-Hub")
ZO_CreateStringId("SI_WRITCRAFTER_SOURCE_MM",                  "Master Merchant")
ZO_CreateStringId("SI_WRITCRAFTER_SOURCE_TTC",                 "Tamriel Trade Centre")
ZO_CreateStringId("SI_WRITCRAFTER_SOURCE_ATT",                 "Arkadius Trade Tools")
ZO_CreateStringId("SI_WRITCRAFTER_LOG_ERRORS",                 "Errors only")
ZO_CreateStringId("SI_WRITCRAFTER_LOG_NORMAL",                 "Normal")
ZO_CreateStringId("SI_WRITCRAFTER_LOG_DEBUG",                  "Debug")

-- Slash command
ZO_CreateStringId("SI_WRITCRAFTER_HELP",                       "Commands:\n/wc settings - open the settings\n/wc stock <item> - how many you have and can use\n/wc price <item> - the price WritCrafter uses\n/wc selftest - check every stack count against the game's own totals\n/wc debug - toggle debug chat messages")
ZO_CreateStringId("SI_WRITCRAFTER_SELFTEST_OK",                "Self-test passed: <<1>> stackable items checked, all counts match the game's own totals (<<2>> skipped: gear or mixed versions).")
ZO_CreateStringId("SI_WRITCRAFTER_SELFTEST_FAIL",              "Self-test found <<1>> mismatch(es) out of <<2>> items checked:")
ZO_CreateStringId("SI_WRITCRAFTER_SELFTEST_ROW",               "<<1>> (ID <<2>>): WritCrafter <<3>>/<<4>>/<<5>>, game <<6>>/<<7>>/<<8>> (backpack/bank/craft bag)")
ZO_CreateStringId("SI_WRITCRAFTER_SELFTEST_MORE",              "...and <<1>> more. Turn on Debug chat messages and run it again to see all of them.")
ZO_CreateStringId("SI_WRITCRAFTER_UNKNOWN_COMMAND",            "Unknown command \"<<1>>\". Type /wc help.")
ZO_CreateStringId("SI_WRITCRAFTER_NEED_ITEM",                  "Add an item link (shift-click an item into chat) or an item ID.")
ZO_CreateStringId("SI_WRITCRAFTER_STOCK",                      "<<1>>: <<2>> backpack, <<3>> bank, <<4>> craft bag. Usable: <<5>>")
ZO_CreateStringId("SI_WRITCRAFTER_STOCK_LOCKED",               "<<1>>: <<2>> backpack, <<3>> bank, <<4>> craft bag. Usable: <<5>> (<<6>> locked)")
ZO_CreateStringId("SI_WRITCRAFTER_PRICE",                      "<<1>>: <<2>>g each (<<3>>)")
ZO_CreateStringId("SI_WRITCRAFTER_PRICE_NONE",                 "<<1>>: no price data")
ZO_CreateStringId("SI_WRITCRAFTER_DEBUG_ON",                   "Debug messages on.")
ZO_CreateStringId("SI_WRITCRAFTER_DEBUG_OFF",                  "Debug messages off.")
