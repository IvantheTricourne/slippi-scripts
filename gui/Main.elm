port module Main exposing (..)

import Array exposing (..)
import Browser
import Bytes exposing (Bytes)
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
import Task

-- model

type alias Model = Maybe Stats
type alias Stats =
    { totalGames : Int
    , wins : Array Player
    , stages : Array String
    , totalLengthSeconds : Float
    , players : Array Player
    , playerStats : Array PlayerStat
    , sagaIcon : String
    }
type alias Player =
    { playerPort : Int
    , tag : String
    , netplayName : String
    , rollbackCode : String
    , characterName : String
    , color : String
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

-- update

type Msg
    = Reset
    | JsonRequested
    | JsonSelected File
    | JsonLoaded String
    | FilesRequested
    | FilesSelected File (List File)
    | FilesLoaded String
    | GotFiles File (List File)
    | Uploaded (Result Http.Error Stats)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Reset ->
            ( Nothing
            , Cmd.none
            )
        GotFiles file files ->
            ( model -- Uploading 0
            , Http.request
                  { method = "POST"
                  , url = "http://localhost:5000/"
                  , headers = []
                  , body = Http.multipartBody (List.map (Http.filePart "files[]") (file::files))
                  , expect = Http.expectJson Uploaded statsDecoder
                  , timeout = Nothing
                  , tracker = Just "upload"
                  }
            )
        Uploaded result ->
            case result of
                Ok stats -> (Just stats, Cmd.none)
                Err _ -> (Nothing, Cmd.none)
        FilesRequested ->
            ( model
            , Select.files [ "*" ] FilesSelected
            )
        FilesSelected file files ->
            ( model
            , Http.request
                  { method = "POST"
                  , url = "http://localhost:5000/"
                  , headers = []
                  , body = Http.multipartBody (List.map (Http.filePart "files[]") (file::files))
                  , expect = Http.expectJson Uploaded statsDecoder
                  , timeout = Nothing
                  , tracker = Just "upload"
                  }
            )
        FilesLoaded str ->
            ( case D.decodeString statsDecoder str of
                  Ok stats -> Just stats
                  Err _ -> Nothing
            , Cmd.none
            )
        JsonRequested ->
            ( model
            , Select.file [ "application/json" ] JsonSelected
            )
        JsonSelected file ->
            ( model
            , Task.perform JsonLoaded (File.toString file)
            )
        JsonLoaded str ->
            ( case D.decodeString statsDecoder str of
                  Ok stats -> Just stats
                  Err _ -> Nothing
            , Cmd.none
            )

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
           , htmlAttribute <| hijackOn "drop" dropDecoder
           ]
    (case model of
         Nothing -> viewInit
         Just stats -> viewStats stats)

viewStats stats =
    let player0 = Maybe.withDefault defaultPlayer <| get 0 stats.players
        player1 = Maybe.withDefault defaultPlayer <| get 1 stats.players
    in
    [ row [ centerX
          , spacing 10
          , padding 5
          ]
        [ renderStatColumn [ Font.color white
                           , Font.alignRight
                           , Font.extraBold
                           , moveLeft 190
                           , spacing 15
                           ]
              [ renderPlayerName player0 ]
        , renderStatColumn [ Font.color white
                           , Font.center
                           , Font.bold
                           , Font.italic
                           , behindContent <| image
                               [ centerX
                               , centerY
                               , Element.mouseOver [ Background.color cyan
                                                   ]
                               , padding 2
                               , Border.rounded 5
                               , Events.onClick Reset
                               , moveUp 25
                               , scale 1.25
                               ]
                                 { src = "rsrc/Characters/Saga Icons/" ++ stats.sagaIcon ++ ".png"
                                 , description = "Logo for set winner"
                                 }
                           , spacing 15
                           ]
            [ "" ]
        , renderStatColumn [ Font.color white
                           , Font.alignLeft
                           , Font.extraBold
                           , moveRight 190
                           , spacing 15
                           ]
              [ renderPlayerName player1 ]
        ]
    , row [ centerX
          , spacing 10
          , padding 10
          ]
        [ renderStatColumn [ Font.color white
                           , Font.alignRight
                           , behindContent <| image
                               [ centerX
                               , centerY
                               , scale 1.5
                               , moveLeft 150
                               , Background.color grey
                               , Border.rounded 5
                               , padding 5
                               ]
                               { src = playerCharImgPath player0
                               , description = player0.rollbackCode
                               }
                           , spacing 15
                           ]
              (listifyPlayerStat <| get 0 stats.playerStats)
        , renderStatColumn [ Font.color white
                           , Font.center
                           , Font.bold
                           , Font.italic
                           , spacing 15
                           ]
            [ "Total Damage"
            , "APM"
            , "Openings / Kill"
            , "Damage / Opening"
            , "Neutral Wins"
            , "Counter Hits"
            , "Favorite Move"
            , "Favorite Kill Move"
            ]
        , renderStatColumn [ Font.color white
                           , Font.alignLeft
                           , Font.glow black 1000
                           , behindContent <| image
                               [ centerX
                               , centerY
                               , scale 1.5
                               , moveRight 150
                               , Background.color grey
                               , Border.rounded 5
                               , padding 5
                               ]
                               { src = playerCharImgPath player1
                               , description = player1.rollbackCode
                               }
                           , spacing 15
                           ]
            (listifyPlayerStat <| get 1 stats.playerStats)
        ]
    , renderStageImgsWithWinner (toList stats.stages) (toList stats.wins)
    ]
viewInit =
    [ row [ spacing 50
          ]
          [ image [ centerX
                  , Element.mouseOver [ Background.color cyan
                                      ]
                  , padding 2
                  , Border.rounded 5
                  , Events.onClick JsonRequested
                  , below <| el
                      [ Font.color white
                      , centerX
                      ] (text "Stats File")
                  ]
                { src = "rsrc/Characters/Saga Icons/Smash.png"
                , description = "Smash Logo Button"
                }
          -- @TODO: once the webserver is done, uncomment this
          -- , image [ centerX
          --         , Element.mouseOver [ Background.color cyan
          --                             ]
          --         , padding 2
          --         , Border.rounded 5
          --         , Events.onClick FilesRequested
          --         , below <| el
          --             [ Font.color white
          --             , centerX
          --             ] (text "Slippi Files")
          --         ]
          -- { src = "rsrc/Characters/Saga Icons/Smash.png"
          -- , description = "Smash Logo Button"
          -- }
          ]
    ]

listifyPlayerStat : Maybe PlayerStat -> List String
listifyPlayerStat mStat =
    case mStat of
        Nothing -> []
        Just stat ->
            [ String.fromInt << round <| stat.totalDamage
            , String.fromInt << round <| stat.avgApm
            , String.fromInt << round <| stat.avgOpeningsPerKill
            , String.fromInt << round <| stat.avgDamagePerOpening
            , String.fromInt stat.neutralWins
            , String.fromInt stat.counterHits
            , let moveName = stat.favoriteMove.moveName
                  timesUsed = stat.favoriteMove.timesUsed
              in moveName ++ " (" ++ String.fromInt timesUsed ++ ")"
            , let killMoveName = stat.favoriteKillMove.moveName
                  timesUsed = stat.favoriteKillMove.timesUsed
              in killMoveName ++ " (" ++ String.fromInt timesUsed ++ ")"
            ]

renderStageImgsWithWinner stages wins =
    row [ Background.color black
        , Border.rounded 5
        , spacing 15
        , padding 10
        , centerX
        ] <|
        List.map2
            (\stageName winnerInfo ->
                 image [ Background.color white
                       , Border.rounded 3
                       , scale 1.1
                       , padding 1
                       , below <| image
                           [ centerX
                           , padding 5
                           ]
                           { src = playerCharIconPath winnerInfo
                           , description = renderPlayerName winnerInfo
                           }
                       ]
                 { src = stageImgPath stageName
                 , description = stageName
                 })
            stages wins

renderWinImgs wins =
    row [ Background.color grey
        , Border.rounded 5
        , spacing 15
        , padding 10
        , centerX
        ] <|
        List.indexedMap
            (\i winnerInfo -> image [ Border.rounded 3
                                    , scale 1.1
                                    , padding 1
                                    ]
                 { src = playerCharIconPath winnerInfo
                 , description = renderPlayerName winnerInfo
                 })
            wins

renderStatColumn styles strings =
    Element.indexedTable styles
        { data = strings
        , columns =
              [ { header = text ""
                , width = px 175
                , view = \_ x -> text x
                }
              ]
        }

renderPlayerName player =
    case player.rollbackCode of
        "n/a" -> case player.netplayName of
                     "No Name" -> player.characterName
                     _ -> player.netplayName
        _ -> player.rollbackCode

-- @TODO: maybe move these all the node side
playerCharImgPath : Player -> String
playerCharImgPath player =
    "rsrc/Characters/Portraits/" ++ player.characterName ++ "/" ++ player.color ++ ".png"

playerCharIconPath : Player -> String
playerCharIconPath player =
    "rsrc/Characters/Stock Icons/" ++ player.characterName ++ "/" ++ player.color ++ ".png"

stageImgPath : String -> String
stageImgPath stageName =
    "rsrc/Stages/Icons/" ++ stageName ++ ".png"

-- elements
black = rgb255 0 0 0
white = rgb255 255 255 255
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
        Nothing -> E.object []
        Just stats ->
            E.object
                [ ("totalGames", E.int stats.totalGames)
                , ("wins", E.array playerEncoder stats.wins)
                , ("stages", E.array E.string stats.stages)
                , ("totalLengthSeconds", E.float stats.totalLengthSeconds)
                , ("players", E.array playerEncoder stats.players)
                , ("playerStats", E.array playerStatEncoder stats.playerStats)
                , ("sagaIcon" , E.string stats.sagaIcon)
                ]

playerEncoder : Player -> E.Value
playerEncoder player =
    E.object
        [ ("port", E.int player.playerPort)
        , ("tag", E.string player.tag)
        , ("netplayName", E.string player.netplayName)
        , ("rollbackCode", E.string player.rollbackCode)
        , ("characterName", E.string player.characterName)
        , ("color", E.string player.color)
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

decoder : D.Decoder Model
decoder = D.nullable statsDecoder

statsDecoder : D.Decoder Stats
statsDecoder =
  D.map7 Stats
    (D.field "totalGames" D.int)
    (D.field "wins" <| D.array playerDecoder)
    (D.field "stages" <| D.array D.string)
    (D.field "totalLengthSeconds" D.float)
    (D.field "players" <| D.array playerDecoder)
    (D.field "playerStats" <| D.array playerStatDecoder)
    (D.field "sagaIcon" <| D.string)


playerDecoder : D.Decoder Player
playerDecoder =
    D.map7 Player
        (D.field "port" D.int)
        (D.field "tag" D.string)
        (D.field "netplayName" D.string)
        (D.field "rollbackCode" D.string)
        (D.field "characterName" D.string)
        (D.field "color" D.string)
        (D.field "idx" D.int)

-- file drops
dropDecoder : D.Decoder Msg
dropDecoder =
  D.at ["dataTransfer","files"] (D.oneOrMore GotFiles File.decoder)

hijackOn : String -> D.Decoder msg -> Html.Attribute msg
hijackOn event hijackDecoder =
  preventDefaultOn event (D.map hijack hijackDecoder)

hijack : msg -> (msg, Bool)
hijack msg =
  (msg, True)

-- default player for handling maybes
defaultPlayer : Player
defaultPlayer =
    { playerPort = 0
    , tag = "XXXX"
    , netplayName = "n/a"
    , rollbackCode = "XXXX#YYYYY"
    , characterName = "Sonic"
    , color = "Emerald"
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
subscriptions _ = Sub.none

-- main

init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( case D.decodeValue decoder flags of
          Ok model -> model
          Err _ -> Nothing
    , Cmd.none
    )

main = Browser.element
       { init = init
       , update = updateWithStorage
       , view = view
       , subscriptions = subscriptions
       }
