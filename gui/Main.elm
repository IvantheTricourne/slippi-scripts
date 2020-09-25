port module Main exposing (..)

import Array exposing (..)
import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import File as File exposing (File)
import File.Select as Select
import Html exposing (Html)
import Html.Events exposing (preventDefaultOn)
import Http as Http
import Json.Decode as D
import Json.Encode as E
import Maybe

-- model

-- type alias Model = Result D.Error Stats
type Model
  = Waiting
  | Uploading Float
  | Done Stats
  | Fail D.Error
type alias Stats =
    { totalGames : Int
    , games : Array Game
    , totalLengthSeconds : Float
    , players : Array Player
    , playerStats : Array PlayerStat
    , sagaIcon : String
    }
type alias Game =
    { stage : String
    , winner : Player
    , players : Array Player
    }
type alias Character =
    { characterName : String
    , color : String
    }
type alias Player =
    { playerPort : Int
    , tag : String
    , netplayName : String
    , rollbackCode : String
    , main : Character
    , secondaries : Array Character
    , idx : Int
    }
type alias PlayerStat =
    { totalDamage : Float
    , neutralWins : Int
    , counterHits : Int
    , avgApm : Float
    , avgOpeningsPerKill : Float
    , avgDamagePerOpening : Float
    , favoriteMove : FavoriteMove
    , favoriteKillMove : FavoriteMove
    }
type alias FavoriteMove =
    { moveName : String
    , timesUsed : Int
    }
type CellValue
    = Single String
    | Dub (String, String)

-- update

type Msg
    = Reset
    | FilesRequested
    | FilesSelected File (List File)
    | GotProgress Http.Progress
    | Uploaded (Result Http.Error Stats)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Reset ->
            ( Waiting
            , Cmd.none
            )
        GotProgress progress ->
            case progress of
                Http.Sending p ->
                    (Uploading (Http.fractionSent p), Cmd.none)

                Http.Receiving _ ->
                    (model, Cmd.none)
        Uploaded result ->
            case result of
                Ok stats -> (Done stats, Cmd.none)
                Err err -> (Fail <| httpErrToJsonErr err, Cmd.none)
        FilesRequested ->
            ( Uploading 0
            , Select.files [ "*" ] FilesSelected
            )
        FilesSelected file files ->
            ( model
            , Http.request
                  { method = "POST"
                  , url = "http://localhost:8080/stats/upload"
                  , headers = []
                  , body = Http.multipartBody (List.map (Http.filePart "multipleFiles") (file::files))
                  , expect = Http.expectJson Uploaded statsDecoder
                  , timeout = Nothing
                  , tracker = Just "upload"
                  }
            )

httpErrToJsonErr : Http.Error -> D.Error
httpErrToJsonErr httpErr =
    case httpErr of
        Http.BadUrl str -> D.Failure "BadUrl" (E.object [("msg", E.string str)])
        Http.Timeout -> D.Failure "Timeout" (E.object [("msg", E.string "response timeout")])
        Http.NetworkError -> D.Failure "NetworkError" (E.object [("msg", E.string "network error")])
        Http.BadStatus int -> D.Failure "Bad Status" (E.object [("msg", E.string "Bad Status")])
        Http.BadBody str -> D.Failure "Bad Body" (E.string str)

-- view
-- @TODO: clean up styles
view : Model -> Html Msg
view model =
    Element.layout [ Background.color black
                   , Font.family [ Font.external
                                       { name = "Roboto"
                                       , url = "https://fonts.googleapis.com/css?family=Roboto"
                                       }
                                 , Font.monospace
                                 ]
                   ] <|
    column [ centerX
           , centerY
           , spacing 10
           ]
    (case model of
         Waiting -> viewInit
         Fail err -> viewFail err
         Uploading pct -> viewProgress pct
         Done stats -> viewStats stats)

viewStats stats =
    let player0 = Maybe.withDefault defaultPlayer <| get 0 stats.players
        player1 = Maybe.withDefault defaultPlayer <| get 1 stats.players
    in
    [ image [ centerX
            , centerY
            , Element.mouseOver [ Background.color cyan
                                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick Reset
            , scale 1.25
            , moveDown 10
            ]
          { src = "rsrc/Characters/Saga Icons/" ++ stats.sagaIcon ++ ".png"
          , description = "Logo for set winner"
          }
    , row [ centerX
          , spacing 10
          , padding 10
          ]
          [ renderStatColumn [ Font.color white
                             , Font.alignRight
                             , onLeft <| image
                                 [ centerX
                                 , centerY
                                 , scale 1.5
                                 , Background.color grey
                                 , Border.rounded 5
                                 , moveRight 25
                                 , moveDown 5
                                 , padding 5
                                 , above <| el
                                     [ centerX
                                     , Font.extraBold
                                     , scale 0.75
                                     ]
                                       (text <| renderPlayerName player0)
                                 , onLeft <| renderSecondaries
                                     [ centerX
                                     , spacing 5
                                     , moveDown 5
                                     , scale 0.7
                                     ]
                                     player0
                                 ]
                                   { src = charImgPath player0.main
                                   , description = renderPlayerName player0
                                   }
                             , spacing 15
                             ]
                [ centerX
                , Font.italic
                , scale 0.6
                , moveRight 80
                , moveUp 4
                ]
                (listifyPlayerStat <| get 0 stats.playerStats)
          , renderStatColumn [ Font.color white
                             , Font.center
                             , Font.bold
                             , Font.italic
                             , spacing 15
                             ]
                []
                [ Single "Total Damage"
                , Single "Damage / Opening"
                , Single "Openings / Kill"
                , Single "Neutral Wins"
                , Single "Counter Hits"
                , Single "APM"
                , Single "Favorite Move"
                , Single "Favorite Kill Move"
                ]
          , renderStatColumn [ Font.color white
                             , Font.alignLeft
                             , onRight <| image
                                 [ centerX
                                 , centerY
                                 , scale 1.5
                                 , Background.color grey
                                 , Border.rounded 5
                                 , moveLeft 25
                                 , moveDown 5
                                 , padding 5
                                 , above <| el
                                     [ centerX
                                     , Font.extraBold
                                     , scale 0.75
                                     ]
                                       (text <| renderPlayerName player1)
                                 , onRight <| renderSecondaries
                                     [ centerX
                                     , spacing 5
                                     , moveDown 5
                                     , scale 0.7
                                     ]
                                     player1
                                 ]
                                   { src = charImgPath player1.main
                                   , description = renderPlayerName player1
                                   }
                           , spacing 15
                           ]
                [ centerX
                , Font.italic
                , scale 0.6
                , moveLeft 80
                , moveUp 4
                ]

            (listifyPlayerStat <| get 1 stats.playerStats)
        ]
    , renderStageImgsWithWinner (toList stats.games)
    ]
viewInit =
    [ image [ centerX
            , Element.mouseOver [ Background.color cyan
                                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick FilesRequested
            , below <| el
                [ Font.color white
                , centerX
                      ] (text "Slippi Files")
            ]
          { src = "rsrc/Characters/Saga Icons/Smash.png"
          , description = "Smash Logo Button"
          }
    ]
viewFail err =
    let msg = D.errorToString err
    in
    [ image [ centerX
            , Element.mouseOver [ Background.color cyan
                                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick FilesRequested
            , below <| el
                [ Font.color white
                , centerX
                ] (text "Slippi Files")
            ]
          { src = "rsrc/Characters/Saga Icons/Smash.png"
          , description = "Smash Logo Button"
         }
    -- @TODO: format this better somehow
    , el [ Background.color white
         , moveDown 50
         ] (text msg)
    ]
viewProgress pct =
    if pct > 0 then
        [ image [ centerX
                , Element.mouseOver [ Background.color cyan
                                    ]
                , padding 2
                , Border.rounded 5
                , Events.onClick FilesRequested
                , below <| el
                    [ Font.color white
                    , centerX
                    ] (text "Slippi Files")
                ]
              { src = "rsrc/Characters/Saga Icons/Smash.png"
              , description = "Smash Logo Button"
              }
        , el [ Font.color white
             , centerX
             , moveDown 50
             ] (text (String.fromInt (round (100 * pct)) ++ "%"))
        ]
    else viewInit

listifyPlayerStat : Maybe PlayerStat -> List CellValue
listifyPlayerStat mStat =
    case mStat of
        Nothing -> []
        Just stat ->
            [ Single << String.fromInt << round <| stat.totalDamage
            , Single << String.fromInt << round <| stat.avgDamagePerOpening
            , Single << String.fromInt << round <| stat.avgOpeningsPerKill
            , Single << String.fromInt <| stat.neutralWins
            , Single << String.fromInt <| stat.counterHits
            , Single << String.fromInt << round <| stat.avgApm
            , Dub (stat.favoriteMove.moveName, String.fromInt stat.favoriteMove.timesUsed)
            , Dub (stat.favoriteKillMove.moveName, String.fromInt stat.favoriteKillMove.timesUsed)
            ]

renderStageImgsWithWinner games =
    row [ Background.color black
        , Border.rounded 5
        , spacing 15
        , padding 10
        , centerX
        , moveDown 25
        ] <|
        List.indexedMap
            (\i gameInfo ->
                 image [ Background.color white
                       , Border.rounded 3
                       , scale 1.1
                       , padding 1
                       , above <| el
                           [ Font.color white
                           , centerX
                           , scale 0.55
                           ]
                           (text << String.fromInt <| i + 1)
                       , below <| image
                           [ centerX
                           , padding 5
                           ]
                           { src = charIconPath gameInfo.winner.main
                           , description = renderPlayerName gameInfo.winner
                           }
                       ]
                 { src = stageImgPath gameInfo.stage
                 , description = gameInfo.stage
                 })
            games

renderStatColumn styles subStyles strings =
    Element.indexedTable styles
        { data = strings
        , columns =
              [ { header = text ""
                , width = px 175
                , view = \_ x ->
                      case x of
                          Single l ->
                              el [] <| text l
                          Dub (l, sub) ->
                              el [ below <| el subStyles
                                       (text sub)
                                 ] (text l)
                }
              ]
        }

renderPlayerName player =
    case player.rollbackCode of
        "n/a" -> case player.netplayName of
                     "No Name" -> player.main.characterName
                     _ -> player.netplayName
        _ -> player.rollbackCode

renderSecondaries styles player =
    column styles <|
        List.map
            (\secondary -> image
                 []
                 { src = charIconPath secondary
                 , description = renderPlayerName player
                 })
            (List.reverse << toList <| player.secondaries)

-- @TODO: maybe move these all the node side
charImgPath : Character -> String
charImgPath character =
    "rsrc/Characters/Portraits/" ++ character.characterName ++ "/" ++ character.color ++ ".png"

charIconPath : Character -> String
charIconPath character =
    "rsrc/Characters/Stock Icons/" ++ character.characterName ++ "/" ++ character.color ++ ".png"

stageImgPath : String -> String
stageImgPath stageName =
    "rsrc/Stages/Icons/" ++ stageName ++ ".png"

-- elements
black = rgb255 0 0 0
white = rgb255 238 236 229
grey = rgb255 25 25 25
red = rgb255 255 0 0
cyan = rgb255 175 238 238

-- ports

port setStorage : E.Value -> Cmd msg

updateWithStorage : Msg -> Model -> ( Model, Cmd Msg )
updateWithStorage msg oldModel =
  let
    ( newModel, cmds ) = update msg oldModel
    eModel = encode newModel
  in
  ( newModel
  , Cmd.batch [ setStorage eModel
              , cmds
              ]
  )

-- codecs

encode : Model -> E.Value
encode model =
    case model of
        Waiting -> E.object []
        Uploading _ -> E.object []
        Fail _ -> E.object []
        Done stats ->
            E.object
                [ ("totalGames", E.int stats.totalGames)
                , ("games", E.array gameEncoder stats.games)
                , ("totalLengthSeconds", E.float stats.totalLengthSeconds)
                , ("players", E.array playerEncoder stats.players)
                , ("playerStats", E.array playerStatEncoder stats.playerStats)
                , ("sagaIcon" , E.string stats.sagaIcon)
                ]

gameEncoder : Game -> E.Value
gameEncoder game =
    E.object
        [ ("stage", E.string game.stage)
        , ("winner", playerEncoder game.winner)
        , ("players", E.array playerEncoder game.players)
        ]

characterEncoder : Character -> E.Value
characterEncoder character =
    E.object
        [ ("characterName", E.string character.characterName)
        , ("color", E.string character.color)
        ]

playerEncoder : Player -> E.Value
playerEncoder player =
    E.object
        [ ("port", E.int player.playerPort)
        , ("tag", E.string player.tag)
        , ("netplayName", E.string player.netplayName)
        , ("rollbackCode", E.string player.rollbackCode)
        , ("main", characterEncoder player.main)
        , ("secondaries", E.array characterEncoder player.secondaries)
        , ("idx", E.int player.idx)
        ]

playerStatEncoder : PlayerStat -> E.Value
playerStatEncoder playerStat =
    E.object
        [ ("totalDamage", E.float playerStat.totalDamage)
        , ("neutralWins", E.int playerStat.neutralWins)
        , ("counterHits", E.int playerStat.counterHits)
        , ("avgApm", E.float playerStat.avgApm)
        , ("avgOpeningsPerKill", E.float playerStat.avgOpeningsPerKill)
        , ("avgDamagePerOpening", E.float playerStat.avgDamagePerOpening)
        , ("favoriteMove", favoriteMoveEncoder playerStat.favoriteMove)
        , ("favoriteKillMove", favoriteMoveEncoder playerStat.favoriteKillMove)
        ]

favoriteMoveEncoder : FavoriteMove -> E.Value
favoriteMoveEncoder favMov =
    E.object
        [ ("moveName", E.string favMov.moveName)
        , ("timesUsed", E.int favMov.timesUsed)
        ]

statsDecoder : D.Decoder Stats
statsDecoder =
  D.map6 Stats
    (D.field "totalGames" D.int)
    (D.field "games" <| D.array gameDecoder)
    (D.field "totalLengthSeconds" D.float)
    (D.field "players" <| D.array playerDecoder)
    (D.field "playerStats" <| D.array playerStatDecoder)
    (D.field "sagaIcon" <| D.string)

gameDecoder : D.Decoder Game
gameDecoder =
    D.map3 Game
        (D.field "stage" D.string)
        (D.field "winner" playerDecoder)
        (D.field "players" <| D.array playerDecoder)

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
        (D.field "main" characterDecoder)
        (D.field "secondaries" <| D.array characterDecoder)
        (D.field "idx" D.int)

-- default player for handling maybes
defaultPlayer : Player
defaultPlayer =
    { playerPort = 0
    , tag = "XXXX"
    , netplayName = "n/a"
    , rollbackCode = "XXXX#YYYYY"
    , main =
          { characterName = "Sonic"
          , color = "Emerald"
          }
    , secondaries = fromList []
    , idx = 5
    }

playerStatDecoder : D.Decoder PlayerStat
playerStatDecoder =
    D.map8 PlayerStat
        (D.field "totalDamage" D.float)
        (D.field "neutralWins" D.int)
        (D.field "counterHits" D.int)
        (D.field "avgApm" D.float)
        (D.field "avgOpeningsPerKill" D.float)
        (D.field "avgDamagePerOpening" D.float)
        (D.field "favoriteMove" favoriteMoveDecoder)
        (D.field "favoriteKillMove" favoriteMoveDecoder)

favoriteMoveDecoder : D.Decoder FavoriteMove
favoriteMoveDecoder =
    D.map2 FavoriteMove
        (D.field "moveName" D.string)
        (D.field "timesUsed" D.int)

-- subscriptions
subscriptions : Model -> Sub Msg
subscriptions model =
  Http.track "upload" GotProgress

-- main

init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( case D.decodeValue statsDecoder flags of
          Err _ -> Waiting
          Ok stats -> Done stats
    , Cmd.none
    )

main = Browser.element
       { init = init
       , update = updateWithStorage
       , view = view
       , subscriptions = subscriptions
       }
