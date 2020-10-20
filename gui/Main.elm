port module Main exposing (..)

import Array
import Browser
import Codec exposing (..)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import File as File exposing (File)
import File.Select as Select
import Html exposing (Html)
import Http as Http
import Json.Decode as D
import Json.Encode as E
import Maybe
import Types exposing (..)



-- model


type StatsStatus
    = Waiting
    | Configuring
    | Uploading Float
    | Done Stats
    | Fail D.Error


type alias Model =
    { modelState : StatsStatus
    , modelConfig : StatsConfig
    }



-- update


type Msg
    = Reset
    | Configure
    | ToggleTotalDamage Bool
    | ToggleFavoriteKillMove Bool
    | FilesRequested
    | FilesSelected File (List File)
    | GotProgress Http.Progress
    | Uploaded (Result Http.Error StatsResponse)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Reset ->
            ( { model | modelState = Waiting }
            , Cmd.none
            )

        Configure ->
            ( { model | modelState = Configuring }
            , Cmd.none
            )

        ToggleTotalDamage val ->
            let
                newCfg cfg =
                    { cfg | totalDamage = val }
            in
            ( { model | modelConfig = newCfg model.modelConfig }
            , Cmd.none
            )

        ToggleFavoriteKillMove val ->
            let
                newCfg cfg =
                    { cfg | favoriteKillMove = val }
            in
            ( { model | modelConfig = newCfg model.modelConfig }
            , Cmd.none
            )

        GotProgress progress ->
            case progress of
                Http.Sending p ->
                    ( { model | modelState = Uploading (Http.fractionSent p) }
                    , Cmd.none
                    )

                Http.Receiving _ ->
                    ( model, Cmd.none )

        Uploaded result ->
            case result of
                Ok statsResponse ->
                    if statsResponse.totalGames == 0 then
                        ( { model
                            | modelState =
                                Fail <|
                                    D.Failure "No valid games found" statsResponse.stats
                          }
                        , Cmd.none
                        )

                    else
                        case D.decodeValue statsDecoder statsResponse.stats of
                            Ok stats ->
                                ( { model | modelState = Done stats }, Cmd.none )

                            Err statsDErr ->
                                ( { model | modelState = Fail statsDErr }, Cmd.none )

                Err err ->
                    ( { model
                        | modelState =
                            Fail <|
                                httpErrToJsonErr err
                      }
                    , Cmd.none
                    )

        FilesRequested ->
            ( { model | modelState = Uploading 0 }
            , Select.files [ "*" ] FilesSelected
            )

        FilesSelected file files ->
            ( model
            , Http.request
                { method = "POST"
                , url = "http://localhost:8080/stats/upload"
                , headers = []
                , body = Http.multipartBody (List.map (Http.filePart "multipleFiles") (file :: files))
                , expect = Http.expectJson Uploaded statsResponseDecoder
                , timeout = Nothing
                , tracker = Just "upload"
                }
            )


httpErrToJsonErr : Http.Error -> D.Error
httpErrToJsonErr httpErr =
    case httpErr of
        Http.BadUrl str ->
            D.Failure "BadUrl" (E.object [ ( "url", E.string str ) ])

        Http.Timeout ->
            D.Failure "Timeout" (E.object [ ( "msg", E.string "response timeout" ) ])

        Http.NetworkError ->
            D.Failure "NetworkError" (E.object [ ( "msg", E.string "server connection issue" ) ])

        Http.BadStatus int ->
            D.Failure "Bad Status" (E.object [ ( "status-code", E.int int ) ])

        Http.BadBody str ->
            D.Failure "Bad Body" (E.string str)



-- view


view : Model -> Html Msg
view model =
    -- @TODO: clean up styles with layoutWith
    Element.layout
        [ Background.color black
        , Font.family
            [ Font.external
                { name = "Roboto"
                , url = "https://fonts.googleapis.com/css?family=Roboto"
                }
            , Font.monospace
            ]
        ]
    <|
        column
            [ centerX
            , centerY
            , spacing 10
            ]
            (case model.modelState of
                Waiting ->
                    viewInit

                Configuring ->
                    viewConfiguration model.modelConfig

                Fail err ->
                    viewFail err

                Uploading pct ->
                    viewProgress pct

                Done stats ->
                    viewStats stats
            )


viewStats stats =
    let
        player0 =
            Maybe.withDefault defaultPlayer <| Array.get 0 stats.players

        player0Wins =
            getPlayerWinCount stats.playerStats 0

        player1 =
            Maybe.withDefault defaultPlayer <| Array.get 1 stats.players

        player1Wins =
            getPlayerWinCount stats.playerStats 1
    in
    [ image
        [ centerX
        , centerY
        , Element.mouseOver
            [ Background.color cyan
            ]
        , padding 2
        , Border.rounded 5
        , Events.onClick Reset
        , scale 1.25
        , moveDown 10
        , onLeft <|
            (player0Wins
                |> String.fromInt
                |> text
                |> el
                    [ Font.color white
                    , Font.extraBold
                    , scale 1.5
                    , moveLeft 35
                    , moveDown 30
                    ]
            )
        , onRight <|
            (player1Wins
                |> String.fromInt
                |> text
                |> el
                    [ Font.color white
                    , Font.extraBold
                    , scale 1.5
                    , moveRight 35
                    , moveDown 30
                    ]
            )
        ]
        { src = "rsrc/Characters/Saga Icons/" ++ stats.sagaIcon ++ "G.png"
        , description = "Logo for set winner"
        }
    , row
        [ centerX
        , spacing 10
        , padding 10
        ]
        [ renderStatColumn
            [ Font.color white
            , Font.alignRight
            , onLeft <|
                image
                    [ centerX
                    , centerY
                    , scale 1.5
                    , useWinnerBackgroundGradient player0Wins player1Wins
                    , Border.rounded 5
                    , moveRight 25
                    , moveDown 5
                    , padding 1
                    , above <|
                        el
                            [ centerX
                            , Font.extraBold
                            , scale 0.75
                            ]
                            (text <| renderPlayerName player0)
                    , onLeft <|
                        renderSecondaries
                            [ centerX
                            , centerY
                            , spacing 5
                            , scale 0.7
                            ]
                            player0
                    ]
                    { src = charImgPath player0.character
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
            (listifyPlayerStat <| Array.get 0 stats.playerStats)
        , renderStatColumn
            [ Font.color white
            , Font.center
            , Font.bold
            , Font.italic
            , spacing 15
            ]
            []
            [ Single "Total Damage"
            , Single "Average Kill %"
            , Single "Damage / Opening"
            , Single "Openings / Kill"
            , Single "Neutral Wins"
            , Single "Counter Hits"
            , Single "APM"
            , Single "Favorite Move"
            , Single "Favorite Kill Move"
            ]
        , renderStatColumn
            [ Font.color white
            , Font.alignLeft
            , onRight <|
                image
                    [ centerX
                    , centerY
                    , scale 1.5
                    , useWinnerBackgroundGradient player1Wins player0Wins
                    , Border.rounded 5
                    , moveLeft 25
                    , moveDown 5
                    , padding 1
                    , above <|
                        el
                            [ centerX
                            , Font.extraBold
                            , scale 0.75
                            ]
                            (text <| renderPlayerName player1)
                    , onRight <|
                        renderSecondaries
                            [ centerX
                            , centerY
                            , spacing 5
                            , scale 0.7
                            ]
                            player1
                    ]
                    { src = charImgPath player1.character
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
            (listifyPlayerStat <| Array.get 1 stats.playerStats)
        ]
    , renderStageImgsWithWinner (Array.toList stats.games)
    ]


viewInit =
    [ row
        [ spacing 100
        ]
        [ image
            [ centerX
            , Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick FilesRequested
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Slippi Files")
            ]
            { src = "rsrc/Characters/Saga Icons/Smash.png"
            , description = "Smash Logo Button"
            }
        , image
            [ centerX
            , Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick Configure
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Configure")
            ]
            { src = "rsrc/Characters/Saga Icons/Smash.png"
            , description = "Smash Logo Button"
            }
        ]
    ]


viewFail err =
    let
        msg =
            D.errorToString err
    in
    [ row [ spacing 100 ]
        [ image
            [ centerX
            , Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick FilesRequested
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Slippi Files")
            ]
            { src = "rsrc/Characters/Saga Icons/Smash.png"
            , description = "Smash Logo Button"
            }
        , image
            [ centerX
            , Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick Configure
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Configure")
            ]
            { src = "rsrc/Characters/Saga Icons/Smash.png"
            , description = "Smash Logo Button"
            }
        ]

    -- @TODO: format this better somehow
    , el
        [ Background.color white
        , moveDown 50
        ]
        (text msg)
    ]


viewConfiguration modelCfg =
    [ el
        [ Font.extraBold
        , Font.color white
        , Font.italic
        , centerX
        ]
        (text "Configure Stats")
    , row [ spacing 100 ]
        [ column []
            [ Input.checkbox []
                { onChange = ToggleTotalDamage
                , icon = Input.defaultCheckbox
                , checked = modelCfg.totalDamage
                , label =
                    Input.labelRight [ Font.color white ]
                        (text "Total Damage")
                }
            ]
        , column []
            [ Input.checkbox []
                { onChange = ToggleFavoriteKillMove
                , icon = Input.defaultCheckbox
                , checked = modelCfg.favoriteKillMove
                , label =
                    Input.labelRight [ Font.color white ]
                        (text "Favorite Kill Move")
                }
            ]
        ]
    , image
        [ centerX
        , Element.mouseOver
            [ Background.color cyan
            ]
        , padding 2
        , Border.rounded 5
        , Events.onClick FilesRequested
        , below <|
            el
                [ Font.color white
                , centerX
                ]
                (text "Slippi Files")
        ]
        { src = "rsrc/Characters/Saga Icons/Smash.png"
        , description = "Smash Logo Button"
        }
    ]


viewProgress pct =
    if pct > 0 then
        [ el
            [ Font.color white
            , Font.italic
            , centerX
            ]
            (text "Computing stats...")
        , el
            [ Font.color white
            , centerX
            ]
            (text (String.fromInt (round (100 * pct)) ++ "%"))
        ]

    else
        viewInit


getPlayerWinCount : Array.Array PlayerStat -> Int -> Int
getPlayerWinCount playerStats idx =
    let
        mPlayerStats =
            Array.get idx playerStats
    in
    case mPlayerStats of
        Nothing ->
            -1

        Just playerStat ->
            playerStat.wins


listifyPlayerStat : Maybe PlayerStat -> List CellValue
listifyPlayerStat mStat =
    let
        handlePossibleZero numVal =
            if numVal == 0 then
                "n/a"

            else
                String.fromInt << round <| numVal
    in
    case mStat of
        Nothing ->
            []

        Just stat ->
            [ Single << String.fromInt << round <| stat.totalDamage
            , Single << handlePossibleZero <| stat.avgs.avgKillPercent
            , Single << String.fromInt << round <| stat.avgs.avgDamagePerOpening
            , Single << handlePossibleZero <| stat.avgs.avgOpeningsPerKill
            , Single << String.fromInt <| stat.neutralWins
            , Single << String.fromInt <| stat.counterHits
            , Single << String.fromInt << round <| stat.avgs.avgApm
            , Dub ( stat.favoriteMove.moveName, String.fromInt stat.favoriteMove.timesUsed )
            , Dub ( stat.favoriteKillMove.moveName, String.fromInt stat.favoriteKillMove.timesUsed )
            ]


useWinnerBackgroundGradient playerWins opponentWins =
    if playerWins > opponentWins then
        Background.gradient
            { angle = 3.14
            , steps = [ black, goldenYellow ]
            }

    else
        Background.gradient
            { angle = 3.14
            , steps = [ black, grey ]
            }


renderStageImgsWithWinner games =
    wrappedRow
        [ Background.color black
        , Border.rounded 5
        , spacing 15
        , padding 10
        , centerX
        , moveDown 25
        ]
    <|
        List.indexedMap renderStageAndWinnerIcon games


renderStageAndWinnerIcon gameNum gameInfo =
    let
        ( colorOpts, stockImg ) =
            if gameInfo.stocks == 4 then
                ( [ Background.color gold, Font.color gold, Font.extraBold ]
                , fourStockCharIconPath gameInfo.winner.character
                )

            else
                ( [ Background.color white, Font.color white ]
                , charIconPath gameInfo.winner.character
                )
    in
    image
        (colorOpts
            ++ [ Border.rounded 3
               , scale 1.1
               , padding 1
               , inFront <|
                    el
                        [ Font.extraBold
                        , Background.color grey
                        , Border.rounded 3
                        , alpha 0.65
                        , centerX
                        , centerY
                        , paddingXY 12 17
                        ]
                        (text gameInfo.length)
               , above <|
                    el
                        [ centerX
                        , scale 0.55
                        ]
                        (text << String.fromInt <| gameNum + 1)
               , below <|
                    image
                        [ centerX
                        , padding 5
                        , onRight <|
                            el [ scale 0.55, moveLeft 5 ]
                                (text << String.fromInt <| gameInfo.stocks)
                        ]
                        { src = stockImg
                        , description = renderPlayerName gameInfo.winner
                        }
               ]
        )
        { src = stageImgPath gameInfo.stage
        , description = gameInfo.stage
        }


renderStatColumn styles subStyles strings =
    Element.indexedTable styles
        { data = strings
        , columns =
            [ { header = text ""
              , width = px 175
              , view =
                    \_ x ->
                        case x of
                            Single l ->
                                el [] <| text l

                            Dub ( l, sub ) ->
                                el
                                    [ below <|
                                        el subStyles
                                            (text sub)
                                    ]
                                    (text l)
              }
            ]
        }


renderPlayerName player =
    case player.rollbackCode of
        "n/a" ->
            case player.netplayName of
                "No Name" ->
                    player.character.characterName

                _ ->
                    player.netplayName

        _ ->
            player.rollbackCode


renderSecondaries styles player =
    column styles <|
        List.map
            (\secondary ->
                image
                    []
                    { src = charIconPath secondary
                    , description = renderPlayerName player
                    }
            )
            (List.reverse << Array.toList <| player.characters)



-- @TODO: maybe move these all the node side


charImgPath : Character -> String
charImgPath character =
    "rsrc/Characters/Portraits/" ++ character.characterName ++ "/" ++ character.color ++ ".png"


charIconPath : Character -> String
charIconPath character =
    "rsrc/Characters/Stock Icons/" ++ character.characterName ++ "/" ++ character.color ++ ".png"


fourStockCharIconPath : Character -> String
fourStockCharIconPath character =
    "rsrc/Characters/Stock Icons/" ++ character.characterName ++ "/" ++ character.color ++ "G" ++ ".png"


stageImgPath : String -> String
stageImgPath stageName =
    "rsrc/Stages/Icons/" ++ stageName ++ ".png"



-- elements


black =
    rgb255 0 0 0


white =
    rgb255 238 236 229


grey =
    rgb255 25 25 25


lighterGrey =
    rgb255 100 100 100


red =
    rgb255 255 0 0


cyan =
    rgb255 175 238 238


gold =
    rgb255 255 215 0


goldenYellow =
    rgb255 255 215 60



-- ports


port setStorage : E.Value -> Cmd msg


updateWithStorage : Msg -> Model -> ( Model, Cmd Msg )
updateWithStorage msg oldModel =
    let
        ( newModel, cmds ) =
            update msg oldModel

        eModel =
            encode newModel
    in
    ( newModel
    , Cmd.batch
        [ setStorage eModel
        , cmds
        ]
    )



-- codecs


encode : Model -> E.Value
encode model =
    E.object
        [ ( "modelState"
          , case model.modelState of
                Waiting ->
                    E.object
                        [ ( "name", E.string "Waiting" )
                        , ( "args", E.null )
                        ]

                Configuring ->
                    E.object
                        [ ( "name", E.string "Configuring" )
                        , ( "args", E.null )
                        ]

                Uploading _ ->
                    E.object []

                Fail _ ->
                    E.object []

                Done stats ->
                    E.object
                        [ ( "name", E.string "Done" )
                        , ( "args", statsEncoder stats )
                        ]
          )
        , ( "modelConfig", statsConfigEncoder model.modelConfig )
        ]


type alias PreModelState =
    { name : String
    , args : E.Value
    }


decodePreModelState : D.Decoder PreModelState
decodePreModelState =
    D.map2 PreModelState
        (D.field "name" D.string)
        (D.field "args" D.value)


decode : D.Decoder Model
decode =
    D.map2 Model
        (D.field "modelState"
            (decodePreModelState
                |> D.andThen
                    (\preModelState ->
                        case preModelState.name of
                            "Waiting" ->
                                D.succeed Waiting

                            "Configuring" ->
                                D.succeed Configuring

                            "Done" ->
                                D.field "args" statsDecoder
                                    |> D.andThen (Done >> D.succeed)

                            other ->
                                D.fail <| "Unsupported model state: " ++ other
                    )
            )
        )
        (D.field "modelConfig" statsConfigDecoder)


statsResponseDecoder : D.Decoder StatsResponse
statsResponseDecoder =
    D.map2 StatsResponse
        (D.field "totalGames" D.int)
        (D.field "stats" D.value)


defaultPlayer : Player
defaultPlayer =
    { playerPort = 0
    , tag = "XXXX"
    , netplayName = "n/a"
    , rollbackCode = "XXXX#YYYYY"
    , character =
        { characterName = "Sonic"
        , color = "Emerald"
        }
    , characters = Array.fromList []
    , idx = 5
    }



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Http.track "upload" GotProgress



-- main


init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( case D.decodeValue decode flags of
        Err fail ->
            { modelState = Fail fail
            , modelConfig =
                { totalDamage = True
                , neutralWins = True
                , counterHits = True
                , avgs =
                    { avgApm = True
                    , avgOpeningsPerKill = True
                    , avgDamagePerOpening = True
                    , avgKillPercent = True
                    }
                , favoriteMove = True
                , favoriteKillMove = True
                }
            }

        Ok model ->
            model
    , Cmd.none
    )


main =
    Browser.element
        { init = init
        , update = updateWithStorage
        , view = view
        , subscriptions = subscriptions
        }
