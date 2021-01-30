module Codec exposing
    ( characterDecoder
    , characterEncoder
    , favoriteMoveDecoder
    , favoriteMoveEncoder
    , gameDecoder
    , gameEncoder
    , messageDecoder
    , messageEncoder
    , playerDecoder
    , playerEncoder
    , playerStatDecoder
    , playerStatEncoder
    , statsConfigDecoder
    , statsConfigEncoder
    , statsDecoder
    , statsEncoder
    , statsResponseDecoder
    , streamStateDecoder
    , streamStateEncoder
    )

import Json.Decode as D
import Json.Decode.Extra as D
import Json.Encode as E
import Types exposing (..)



-- encoders


maybe def f mVal =
    case mVal of
        Nothing ->
            def

        Just val ->
            f val


streamStateEncoder : StreamState -> E.Value
streamStateEncoder ss =
    E.object
        [ ( "players", E.array playerTypeEncoder ss.players )
        , ( "endGames", E.list endGamePayloadEncoder ss.endGames )
        , ( "currentPcts", E.array E.float ss.currentPcts )
        , ( "currentChars", E.array characterEncoder ss.currentChars )
        ]


messageEncoder : Message -> E.Value
messageEncoder msg =
    case msg of
        NewGame payload ->
            E.object
                [ ( "type", E.string "NewGame" )
                , ( "payload", newGamePayloadEncoder payload )
                ]

        EndGame payload ->
            E.object
                [ ( "type", E.string "EndGame" )
                , ( "payload", endGamePayloadEncoder payload )
                ]

        PercentChange payload ->
            E.object
                [ ( "type", E.string "PercentChange" )
                , ( "payload", percentChangePayloadEncoder payload )
                ]

        StockChange payload ->
            E.object
                [ ( "type", E.string "StockChange" )
                , ( "payload", stockChangePayloadEncoder payload )
                ]

        CharacterChange payload ->
            E.object
                [ ( "type", E.string "CharacterChange" )
                , ( "payload", characterChangePayloadEncoder payload )
                ]


newGamePayloadEncoder : NewGamePayload -> E.Value
newGamePayloadEncoder payload =
    E.object
        [ ( "slpVersion", maybe E.null E.string payload.slpVersion )
        , ( "isTeams", maybe E.null E.bool payload.isTeams )
        , ( "isPAL", maybe E.null E.bool payload.isPAL )
        , ( "stageId", maybe E.null E.int payload.stageId )
        , ( "players", E.list playerTypeEncoder payload.players )
        ]


playerTypeEncoder : PlayerType -> E.Value
playerTypeEncoder playerType =
    E.object
        [ ( "playerIndex", E.int playerType.playerIndex )
        , ( "port", E.int playerType.playerPort )
        , ( "characterId", maybe E.null E.int playerType.characterId )
        , ( "characterColor", maybe E.null E.int playerType.characterColor )
        , ( "startStocks", maybe E.null E.int playerType.startStocks )
        , ( "type", maybe E.null E.int playerType.playerType )
        , ( "teamId", maybe E.null E.int playerType.teamId )
        , ( "controllerFix", maybe E.null E.string playerType.controllerFix )
        , ( "nametag", maybe E.null E.string playerType.nametag )
        ]


endGamePayloadEncoder : EndGamePayload -> E.Value
endGamePayloadEncoder payload =
    E.object
        [ ( "gameEndMethod", maybe E.null E.int payload.gameEndMethod )
        , ( "lrasInitiatorIndex", maybe E.null E.int payload.lrasInitiatorIndex )
        , ( "winnerPlayerIndex", E.int payload.winnerPlayerIndex )
        ]


percentChangePayloadEncoder : PercentChangePayload -> E.Value
percentChangePayloadEncoder pc =
    E.object
        [ ( "playerIndex", E.int pc.playerIndex )
        , ( "percent", E.float pc.percent )
        ]


stockChangePayloadEncoder : StockChangePayload -> E.Value
stockChangePayloadEncoder sc =
    E.object
        [ ( "playerIndex", E.int sc.playerIndex )
        , ( "stocksRemaining", E.int sc.stocksRemaining )
        ]


characterChangePayloadEncoder : CharacterChangePayload -> E.Value
characterChangePayloadEncoder cc =
    E.object
        [ ( "characters", E.list characterEncoder cc.characters )
        ]


statsConfigEncoder : StatsConfig -> E.Value
statsConfigEncoder statsCfg =
    E.object
        [ ( "totalDamage", E.bool statsCfg.totalDamage )
        , ( "neutralWins", E.bool statsCfg.neutralWins )
        , ( "counterHits", E.bool statsCfg.counterHits )
        , ( "avgApm", E.bool statsCfg.avgApm )
        , ( "avgOpeningsPerKill", E.bool statsCfg.avgOpeningsPerKill )
        , ( "avgDamagePerOpening", E.bool statsCfg.avgDamagePerOpening )
        , ( "avgKillPercent", E.bool statsCfg.avgKillPercent )
        , ( "favoriteMove", E.bool statsCfg.favoriteMove )
        , ( "favoriteKillMove", E.bool statsCfg.favoriteKillMove )
        , ( "setCountAndWinner", E.bool statsCfg.setCountAndWinner )
        , ( "stages", E.bool statsCfg.stages )
        ]


statsEncoder : Stats -> E.Value
statsEncoder stats =
    E.object
        [ ( "games", E.array gameEncoder stats.games )
        , ( "totalLengthSeconds", E.float stats.totalLengthSeconds )
        , ( "players", E.array playerEncoder stats.players )
        , ( "playerStats", E.array playerStatEncoder stats.playerStats )
        , ( "sagaIcon", E.string stats.sagaIcon )
        ]


gameEncoder : Game -> E.Value
gameEncoder game =
    E.object
        [ ( "stage", E.string game.stage )
        , ( "winner", playerEncoder game.winner )
        , ( "stocks", E.int game.stocks )
        , ( "players", E.array playerEncoder game.players )
        , ( "length", E.string game.length )
        ]


characterEncoder : Character -> E.Value
characterEncoder character =
    E.object
        [ ( "characterName", E.string character.characterName )
        , ( "color", E.string character.color )
        ]


playerEncoder : Player -> E.Value
playerEncoder player =
    E.object
        [ ( "port", E.int player.playerPort )
        , ( "tag", E.string player.tag )
        , ( "netplayName", E.string player.netplayName )
        , ( "rollbackCode", E.string player.rollbackCode )
        , ( "character", characterEncoder player.character )
        , ( "characters", E.array characterEncoder player.characters )
        , ( "idx", E.int player.idx )
        ]


playerStatEncoder : PlayerStat -> E.Value
playerStatEncoder playerStat =
    E.object
        [ ( "totalDamage", E.float playerStat.totalDamage )
        , ( "neutralWins", E.int playerStat.neutralWins )
        , ( "counterHits", E.int playerStat.counterHits )
        , ( "avgApm", E.float playerStat.avgApm )
        , ( "avgOpeningsPerKill", E.float playerStat.avgOpeningsPerKill )
        , ( "avgDamagePerOpening", E.float playerStat.avgDamagePerOpening )
        , ( "avgKillPercent", E.float playerStat.avgKillPercent )
        , ( "favoriteMove", favoriteMoveEncoder playerStat.favoriteMove )
        , ( "favoriteKillMove", favoriteMoveEncoder playerStat.favoriteKillMove )
        , ( "wins", E.int playerStat.wins )
        ]


favoriteMoveEncoder : FavoriteMove -> E.Value
favoriteMoveEncoder favMov =
    E.object
        [ ( "moveName", E.string favMov.moveName )
        , ( "timesUsed", E.int favMov.timesUsed )
        ]



-- decoders


streamStateDecoder : D.Decoder StreamState
streamStateDecoder =
    D.map4 StreamState
        (D.field "players" <| D.array playerTypeDecoder)
        (D.field "endGames" <| D.list endGamePayloadDecoder)
        (D.field "currentPcts" <| D.array D.float)
        (D.field "currentChars" <| D.array characterDecoder)


messageRecordDecoder : D.Decoder MessageRecord
messageRecordDecoder =
    D.map2 MessageRecord
        (D.field "type" D.string)
        (D.field "payload" D.value)


messageDecoder : D.Decoder Message
messageDecoder =
    messageRecordDecoder
        |> D.andThen
            (\msgRec ->
                case msgRec.msgRecType of
                    "NewGame" ->
                        D.field "payload" newGamePayloadDecoder |> D.andThen (NewGame >> D.succeed)

                    "EndGame" ->
                        D.field "payload" endGamePayloadDecoder |> D.andThen (EndGame >> D.succeed)

                    "PercentChange" ->
                        D.field "payload" percentChangePayloadDecoder |> D.andThen (PercentChange >> D.succeed)

                    "StockChange" ->
                        D.field "payload" stockChangePayloadDecoder |> D.andThen (StockChange >> D.succeed)

                    "CharacterChange" ->
                        D.field "payload" characterChangePayloadDecoder |> D.andThen (CharacterChange >> D.succeed)

                    otherwise ->
                        D.fail ("Unknown message type: " ++ otherwise)
            )


newGamePayloadDecoder : D.Decoder NewGamePayload
newGamePayloadDecoder =
    D.map5 NewGamePayload
        (D.field "slpVersion" <| D.nullable D.string)
        (D.field "isTeams" <| D.nullable D.bool)
        (D.field "isPAL" <| D.nullable D.bool)
        (D.field "stageId" <| D.nullable D.int)
        (D.field "players" <| D.list playerTypeDecoder)


playerTypeDecoder : D.Decoder PlayerType
playerTypeDecoder =
    D.succeed PlayerType
        |> D.andMap (D.field "playerIndex" D.int)
        |> D.andMap (D.field "port" D.int)
        |> D.andMap (D.field "characterId" <| D.nullable D.int)
        |> D.andMap (D.field "characterColor" <| D.nullable D.int)
        |> D.andMap (D.field "startStocks" <| D.nullable D.int)
        |> D.andMap (D.field "type" <| D.nullable D.int)
        |> D.andMap (D.field "teamId" <| D.nullable D.int)
        |> D.andMap (D.field "controllerFix" <| D.nullable D.string)
        |> D.andMap (D.field "nametag" <| D.nullable D.string)


endGamePayloadDecoder : D.Decoder EndGamePayload
endGamePayloadDecoder =
    D.map3 EndGamePayload
        (D.field "gameEndMethod" <| D.nullable D.int)
        (D.field "lrasInitiatorIndex" <| D.nullable D.int)
        (D.field "winnerPlayerIndex" D.int)


percentChangePayloadDecoder : D.Decoder PercentChangePayload
percentChangePayloadDecoder =
    D.map2 PercentChangePayload
        (D.field "playerIndex" D.int)
        (D.field "percent" D.float)


stockChangePayloadDecoder : D.Decoder StockChangePayload
stockChangePayloadDecoder =
    D.map2 StockChangePayload
        (D.field "playerIndex" D.int)
        (D.field "stocksRemaining" D.int)


characterChangePayloadDecoder : D.Decoder CharacterChangePayload
characterChangePayloadDecoder =
    D.map CharacterChangePayload
        (D.field "characters" <| D.list characterDecoder)


statsResponseDecoder : D.Decoder StatsResponse
statsResponseDecoder =
    D.map2 StatsResponse
        (D.field "totalGames" D.int)
        (D.field "stats" D.value)


statsConfigDecoder : D.Decoder StatsConfig
statsConfigDecoder =
    D.succeed StatsConfig
        |> D.andMap (D.field "totalDamage" D.bool)
        |> D.andMap (D.field "neutralWins" D.bool)
        |> D.andMap (D.field "counterHits" D.bool)
        |> D.andMap (D.field "avgApm" D.bool)
        |> D.andMap (D.field "avgOpeningsPerKill" D.bool)
        |> D.andMap (D.field "avgDamagePerOpening" D.bool)
        |> D.andMap (D.field "avgKillPercent" D.bool)
        |> D.andMap (D.field "favoriteMove" D.bool)
        |> D.andMap (D.field "favoriteKillMove" D.bool)
        |> D.andMap (D.field "setCountAndWinner" D.bool)
        |> D.andMap (D.field "stages" D.bool)


statsDecoder : D.Decoder Stats
statsDecoder =
    D.map5 Stats
        (D.field "games" <| D.array gameDecoder)
        (D.field "totalLengthSeconds" D.float)
        (D.field "players" <| D.array playerDecoder)
        (D.field "playerStats" <| D.array playerStatDecoder)
        (D.field "sagaIcon" <| D.string)


gameDecoder : D.Decoder Game
gameDecoder =
    D.map5 Game
        (D.field "stage" D.string)
        (D.field "winner" playerDecoder)
        (D.field "stocks" D.int)
        (D.field "players" <| D.array playerDecoder)
        (D.field "length" D.string)


characterDecoder : D.Decoder Character
characterDecoder =
    D.map2 Character
        (D.field "characterName" D.string)
        (D.field "color" D.string)


playerDecoder : D.Decoder Player
playerDecoder =
    D.map7 Player
        (D.field "port" D.int)
        (D.field "tag" D.string)
        (D.field "netplayName" D.string)
        (D.field "rollbackCode" D.string)
        (D.field "character" characterDecoder)
        (D.field "characters" <| D.array characterDecoder)
        (D.field "idx" D.int)


playerStatDecoder : D.Decoder PlayerStat
playerStatDecoder =
    D.succeed PlayerStat
        |> D.andMap (D.field "totalDamage" D.float)
        |> D.andMap (D.field "neutralWins" D.int)
        |> D.andMap (D.field "counterHits" D.int)
        |> D.andMap (D.field "avgApm" D.float)
        |> D.andMap (D.field "avgOpeningsPerKill" D.float)
        |> D.andMap (D.field "avgDamagePerOpening" D.float)
        |> D.andMap (D.field "avgKillPercent" D.float)
        |> D.andMap (D.field "favoriteMove" favoriteMoveDecoder)
        |> D.andMap (D.field "favoriteKillMove" favoriteMoveDecoder)
        |> D.andMap (D.field "wins" D.int)


favoriteMoveDecoder : D.Decoder FavoriteMove
favoriteMoveDecoder =
    D.map2 FavoriteMove
        (D.field "moveName" D.string)
        (D.field "timesUsed" D.int)
