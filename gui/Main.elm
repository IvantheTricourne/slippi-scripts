port module Main exposing (..)

import Array
import Browser
import Codec exposing (..)
import Colors exposing (..)
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
import Resources exposing (..)
import Stream exposing (..)
import Types exposing (..)



-- model


type StatsStatus
    = Waiting
    | Streaming
    | Configuring (Maybe Stats)
    | Uploading Float
    | Done Stats
    | Fail D.Error


type alias Model =
    { modelState : StatsStatus
    , modelConfig : StatsConfig
    , streamState : StreamState
    , lastMessage : Maybe Message
    , disabledStats : Int
    , stagePage : Int
    }



-- update


type Msg
    = Goto StatsStatus
    | Configure (Maybe Stats)
    | UpdatePage (Int -> Int)
    | Toggle StatsConfigField Bool
    | FilesRequested
    | FilesSelected File (List File)
    | GotProgress Http.Progress
    | Uploaded (Result Http.Error StatsResponse)
    | Recv String


toggleField : StatsConfigField -> Bool -> StatsConfig -> StatsConfig
toggleField field val statsCfg =
    case field of
        TotalDamageF ->
            { statsCfg | totalDamage = val }

        NeutralWinsF ->
            { statsCfg | neutralWins = val }

        CounterHitsF ->
            { statsCfg | counterHits = val }

        AvgApmF ->
            { statsCfg | avgApm = val }

        AvgOpeningsPerKillF ->
            { statsCfg | avgOpeningsPerKill = val }

        AvgDamagePerOpeningF ->
            { statsCfg | avgDamagePerOpening = val }

        AvgKillPercentF ->
            { statsCfg | avgKillPercent = val }

        FavoriteMoveF ->
            { statsCfg | favoriteMove = val }

        FavoriteKillMoveF ->
            { statsCfg | favoriteKillMove = val }

        SetCountAndWinnerF ->
            { statsCfg | setCountAndWinner = val }

        StagesF ->
            { statsCfg | stages = val }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Goto status ->
            ( { model | modelState = status }
            , Cmd.none
            )

        Configure mStats ->
            ( { model | modelState = Configuring mStats }
            , Cmd.none
            )

        UpdatePage incDec ->
            ( { model | stagePage = incDec model.stagePage }
            , Cmd.none
            )

        Toggle field bool ->
            ( { model
                | modelConfig = toggleField field bool model.modelConfig
                , disabledStats =
                    case field of
                        -- General layouts don't count
                        SetCountAndWinnerF ->
                            model.disabledStats

                        StagesF ->
                            model.disabledStats

                        _ ->
                            if bool then
                                model.disabledStats - 1

                            else
                                model.disabledStats + 1
              }
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
            ( { model
                | modelState = Uploading 0
                , stagePage = 0
              }
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

        Recv message ->
            case D.decodeString messageDecoder message of
                Err err ->
                    ( model
                    , log (D.errorToString err)
                    )

                Ok newMsg ->
                    ( { model
                        | lastMessage = Just newMsg
                        , streamState = updateStateWithMessage model.streamState newMsg
                      }
                    , Cmd.none
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
        [ Background.color lighterGrey
        , alpha 1.0
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
                    viewInit model

                Streaming ->
                    viewStream model

                Configuring mStats ->
                    case mStats of
                        Nothing ->
                            viewConfiguration model.modelConfig mStats

                        Just stats ->
                            [ column
                                [ centerX
                                , centerY
                                , spacing 10
                                , inFront <|
                                    column
                                        [ centerX
                                        , centerY
                                        , spacing 10
                                        ]
                                        (viewConfiguration model.modelConfig mStats)
                                ]
                                (viewStats stats model.modelConfig model.disabledStats model.stagePage 0.1)
                            ]

                Fail err ->
                    viewFail err

                Uploading pct ->
                    viewProgress model pct

                Done stats ->
                    viewStats stats model.modelConfig model.disabledStats model.stagePage 1
            )


viewStats stats modelCfg disabledStats stagePage alphaVal =
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
    [ column
        [ spacing <| 10 + disabledStats * 5
        , alpha alphaVal
        ]
        [ if modelCfg.setCountAndWinner then
            image
                [ centerX
                , centerY
                , Element.mouseOver
                    [ Background.color cyan
                    ]
                , padding 2
                , Border.rounded 5
                , Events.onClick <| Goto Waiting
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
                (winnerSagaIcon stats.sagaIcon)

          else
            image
                [ centerX
                , centerY
                , Element.mouseOver
                    [ Background.color cyan
                    ]
                , padding 2
                , Border.rounded 5
                , Events.onClick <| Goto Waiting
                , scale 1.25
                , moveDown 10
                ]
                smashLogo
        , row
            [ centerX
            , centerY
            , spacing 10
            , padding 10
            ]
            [ renderStatColumn modelCfg
                [ Font.color white
                , Font.alignRight
                , onLeft <|
                    image
                        [ centerX
                        , centerY
                        , scale 1.5
                        , useWinnerBackgroundGradient player0Wins player1Wins modelCfg.setCountAndWinner
                        , Border.rounded 5
                        , moveRight 55
                        , moveUp <| -5 + toFloat disabledStats * 2.5
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
            , renderStatColumn modelCfg
                [ Font.color white
                , Font.center
                , Font.bold
                , Font.italic
                , spacing 15
                , Events.onDoubleClick <| Configure (Just stats)
                ]
                []
                [ Single .totalDamage "Total Damage"
                , Single .avgKillPercent "Average Kill Percent"
                , Single .avgDamagePerOpening "Damage / Opening"
                , Single .avgOpeningsPerKill "Openings / Kill"
                , Single .neutralWins "Neutral Wins"
                , Single .counterHits "Counter Hits"
                , Single .avgApm "APM"
                , Single .favoriteMove "Favorite Move"
                , Single .favoriteKillMove "Favorite Kill Move"
                ]
            , renderStatColumn modelCfg
                [ Font.color white
                , Font.alignLeft
                , onRight <|
                    image
                        [ centerX
                        , centerY
                        , scale 1.5
                        , useWinnerBackgroundGradient player1Wins player0Wins modelCfg.setCountAndWinner
                        , Border.rounded 5
                        , moveLeft 55
                        , moveUp <| -5 + toFloat disabledStats * 2.5
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
        , if modelCfg.stages then
            renderStageImgsWithWinner (Array.toList stats.games) disabledStats stagePage

          else
            none
        ]
    ]


viewStream model =
    let
        showPlayerCharacterIcons player char =
            row
                [ centerX
                , spacing 2
                , scale 0.25
                , moveUp 20
                ]
                (List.repeat
                    (Maybe.withDefault 0 player.startStocks)
                    -- (image
                    --     []
                    --     { src = charIconPath char
                    --     , description = ""
                    --     }
                    -- )
                    (el
                        [ Font.color <|
                            case player.playerPort of
                                1 ->
                                    red

                                2 ->
                                    blue

                                _ ->
                                    white
                        , scale 4
                        , padding 5
                        , moveUp 10
                        ]
                        (text ".")
                    )
                )

        showPlayerCharacter char =
            image
                [ centerX
                , scale 0.175
                , moveUp 98

                -- , Background.color grey
                -- , Border.rounded 5
                , paddingXY 25 5
                ]
                { src = charImgPath char
                , description = ""
                }

        showPlayerPcts pct =
            let
                roundedText =
                    String.fromInt << round <| pct
            in
            el
                [ Font.color white
                , onRight <|
                    el
                        [ scale 0.3
                        , moveLeft 5
                        , moveDown 4
                        , behindContent <|
                            el
                                [ Font.color black
                                , Font.extraBold
                                ]
                                (text "%")
                        ]
                        (text "%")
                , behindContent <|
                    el
                        [ Font.color black
                        , Font.extraBold
                        ]
                        (text roundedText)
                ]
                (text roundedText)

        showPlayerInfo moveLR playerIdx =
            let
                pctElem =
                    Array.get playerIdx model.streamState.currentPcts
                        |> Maybe.map showPlayerPcts
                        |> Maybe.withDefault none
            in
            el
                [ centerX
                , paddingXY 5 2
                , scale 4.0
                , below <|
                    Maybe.withDefault none
                        (Maybe.map2 showPlayerCharacterIcons
                            (Array.get playerIdx model.streamState.players)
                            (Array.get playerIdx model.streamState.currentChars)
                        )
                , behindContent <|
                    Maybe.withDefault none
                        (Maybe.map showPlayerCharacter
                            (Array.get playerIdx model.streamState.currentChars)
                        )
                , moveLR
                , moveDown 25

                -- , Font.shadow
                --     { offset = ( 0, -1 )
                --     , blur = 3
                --     , color = black
                --     }
                ]
                pctElem
    in
    [ image
        [ Element.mouseOver
            [ Background.color cyan
            ]
        , padding 2
        , Border.rounded 5
        , Events.onClick <| Goto Streaming
        , centerX
        , centerY
        , above <|
            el
                [ Font.color white
                , scale 1.2

                -- , Font.extraBold
                , Font.italic
                , Font.underline
                , behindContent <|
                    el
                        [ Font.color black
                        , Font.extraBold
                        , Font.underline
                        ]
                        (text "The Sundaez Series")
                , centerX
                , moveUp 3
                ]
                (text "The Sundaez Series")
        , onLeft (showPlayerInfo (moveLeft 150) 0)
        , onRight (showPlayerInfo (moveRight 150) 1)
        ]
        smashLogo
    ]


viewInit model =
    [ row
        [ spacing 100
        , centerX
        ]
        [ image
            [ Element.mouseOver
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
                    (text "Files")
            ]
            smashLogo
        , image
            [ Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick <| Goto Streaming
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Stream")
            ]
            smashLogo
        , image
            [ Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick <| Configure Nothing
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Configure")
            ]
            smashLogo
        ]
    ]


viewFail err =
    let
        msg =
            D.errorToString err
    in
    [ row
        [ spacing 100
        , centerX
        ]
        [ image
            [ Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick <| Goto Streaming
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Files")
            ]
            smashLogo
        , image
            [ Element.mouseOver
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
                    (text "Stream")
            ]
            smashLogo
        , image
            [ Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick <| Configure Nothing
            , below <|
                el
                    [ Font.color white
                    , centerX
                    ]
                    (text "Configure")
            ]
            smashLogo
        ]

    -- @TODO: format this better somehow
    , el
        [ Background.color white
        , moveDown 50
        ]
        (text msg)
    ]


viewConfiguration modelCfg mStats =
    [ column
        [ spacing 50
        , Font.color white
        ]
        [ el
            [ Font.extraBold
            , scale 1.25
            , moveUp 20
            , centerX
            , below <|
                el
                    [ centerX
                    , moveUp 10
                    , below <|
                        el
                            [ centerX
                            , scale 0.4
                            , Font.italic
                            ]
                            (text "Please choose at least 6 stats! :)")
                    ]
                    (text "____________________________")
            ]
            (text "Configure Stats")
        , row
            [ spacing 75
            , centerX
            ]
            [ column [ spacing 10 ]
                [ Input.checkbox []
                    { onChange = Toggle TotalDamageF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.totalDamage
                    , label =
                        Input.labelRight []
                            (text "Total Damage")
                    }
                , Input.checkbox []
                    { onChange = Toggle NeutralWinsF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.neutralWins
                    , label =
                        Input.labelRight []
                            (text "Neutral Wins")
                    }
                , Input.checkbox []
                    { onChange = Toggle CounterHitsF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.counterHits
                    , label =
                        Input.labelRight []
                            (text "Counter Hits")
                    }
                , Input.checkbox []
                    { onChange = Toggle FavoriteMoveF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.favoriteMove
                    , label =
                        Input.labelRight []
                            (text "Favorite Move")
                    }
                , Input.checkbox []
                    { onChange = Toggle FavoriteKillMoveF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.favoriteKillMove
                    , label =
                        Input.labelRight []
                            (text "Favorite Kill Move")
                    }
                ]
            , column [ spacing 15 ]
                [ Input.checkbox []
                    { onChange = Toggle AvgOpeningsPerKillF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.avgOpeningsPerKill
                    , label =
                        Input.labelRight []
                            (text "Openings / Kill")
                    }
                , Input.checkbox []
                    { onChange = Toggle AvgDamagePerOpeningF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.avgDamagePerOpening
                    , label =
                        Input.labelRight []
                            (text "Damage / Opening")
                    }
                , Input.checkbox []
                    { onChange = Toggle AvgKillPercentF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.avgKillPercent
                    , label =
                        Input.labelRight []
                            (text "Average Kill Percent")
                    }
                , Input.checkbox []
                    { onChange = Toggle AvgApmF
                    , icon = Input.defaultCheckbox
                    , checked = modelCfg.avgApm
                    , label =
                        Input.labelRight []
                            (text "APM")
                    }
                ]
            ]
        , el
            [ Font.extraBold
            , scale 1.25
            , moveUp 20
            , centerX
            , below <|
                el
                    [ centerX
                    , moveDown 2
                    , scale 0.5
                    , Font.italic
                    ]
                    (text "General Layout Stats")
            ]
            (text "____________________________")
        , row
            [ spacing 50
            , centerX
            ]
            [ Input.checkbox []
                { onChange = Toggle SetCountAndWinnerF
                , icon = Input.defaultCheckbox
                , checked = modelCfg.setCountAndWinner
                , label =
                    Input.labelRight []
                        (text "Set Count + Winner")
                }
            , Input.checkbox []
                { onChange = Toggle StagesF
                , icon = Input.defaultCheckbox
                , checked = modelCfg.stages
                , label =
                    Input.labelRight []
                        (text "Stages + Stocks")
                }
            ]
        , image
            [ centerX
            , Element.mouseOver
                [ Background.color cyan
                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick <|
                Goto
                    (case mStats of
                        Nothing ->
                            Waiting

                        Just stats ->
                            Done stats
                    )
            , below <|
                el [ centerX ]
                    (text "Save")
            ]
            smashLogo
        ]
    ]


viewProgress model pct =
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
        viewInit model


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
            [ Single .totalDamage << String.fromInt << round <| stat.totalDamage
            , Single .avgKillPercent << handlePossibleZero <| stat.avgKillPercent
            , Single .avgDamagePerOpening << String.fromInt << round <| stat.avgDamagePerOpening
            , Single .avgOpeningsPerKill << handlePossibleZero <| stat.avgOpeningsPerKill
            , Single .neutralWins << String.fromInt <| stat.neutralWins
            , Single .counterHits << String.fromInt <| stat.counterHits
            , Single .avgApm << String.fromInt << round <| stat.avgApm
            , Dub .favoriteMove stat.favoriteMove.moveName (String.fromInt stat.favoriteMove.timesUsed)
            , Dub .favoriteKillMove stat.favoriteKillMove.moveName (String.fromInt stat.favoriteKillMove.timesUsed)
            ]


useWinnerBackgroundGradient playerWins opponentWins showWinner =
    if playerWins > opponentWins && showWinner then
        Background.gradient
            { angle = 3.14
            , steps = [ black, goldenYellow ]
            }

    else
        Background.gradient
            { angle = 3.14
            , steps = [ black, grey ]
            }


renderStageImgsWithWinner games disabledStats stagePage =
    let
        renderedStageImgs =
            List.indexedMap renderStageAndWinnerIcon games

        ( totalPages, pages ) =
            paginateStageImgs renderedStageImgs 0
    in
    wrappedRow
        [ Background.color black
        , Border.rounded 5
        , spacing 15
        , padding 10
        , centerX
        , moveDown <| 25 + (toFloat disabledStats * 5)
        , below <|
            if totalPages > 1 then
                el
                    [ Font.color grey
                    , Font.extraBold
                    , scale 0.75
                    , centerX
                    , moveDown 50
                    , onLeft <|
                        el
                            [ Font.color grey
                            , Font.extraBold
                            , paddingXY 20 10
                            , Element.mouseOver
                                [ Background.color lighterGrey
                                ]
                            , Border.rounded 6
                            , centerY
                            , moveLeft 10
                            , moveUp 10
                            , Events.onClick <| UpdatePage ((-) 1)
                            ]
                            (text "<")
                    , onRight <|
                        el
                            [ Font.color grey
                            , Font.extraBold
                            , paddingXY 20 10
                            , Element.mouseOver
                                [ Background.color lighterGrey
                                ]
                            , Border.rounded 6
                            , centerY
                            , moveRight 10
                            , moveUp 10
                            , Events.onClick <| UpdatePage ((+) 1)
                            ]
                            (text ">")
                    ]
                    (stagePage
                        |> remainderBy totalPages
                        >> abs
                        >> (+) 1
                        |> String.fromInt
                        |> text
                    )

            else
                none
        ]
    <|
        case Array.get (abs << remainderBy totalPages <| stagePage) pages of
            Nothing ->
                []

            Just stages ->
                stages


paginateStageImgs renderedStageImgs totalPages =
    if List.isEmpty renderedStageImgs then
        ( totalPages, Array.empty )

    else
        let
            ( pageCount, pages ) =
                paginateStageImgs (List.drop 10 renderedStageImgs) totalPages

            newPage =
                Array.fromList [ List.take 10 renderedStageImgs ]
        in
        ( pageCount + 1, Array.append newPage pages )


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


renderStatColumn statsConfig styles subStyles cellVals =
    let
        toggledCellVals =
            List.concatMap
                (\cellVal ->
                    case cellVal of
                        Single f _ ->
                            if f statsConfig then
                                [ cellVal ]

                            else
                                []

                        Dub f _ _ ->
                            if f statsConfig then
                                [ cellVal ]

                            else
                                []
                )
                cellVals
    in
    Element.indexedTable styles
        { data = toggledCellVals
        , columns =
            [ { header = text ""
              , width = px 200
              , view =
                    \_ x ->
                        case x of
                            Single _ l ->
                                el [] <| text l

                            Dub _ l sub ->
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



-- ports


port setStorage : E.Value -> Cmd msg


port log : String -> Cmd msg


port messageReceiver : (String -> msg) -> Sub msg


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



-- model codecs


encodeModelState : StatsStatus -> E.Value
encodeModelState status =
    case status of
        Waiting ->
            E.object
                [ ( "name", E.string "Waiting" )
                , ( "args", E.null )
                ]

        Streaming ->
            E.object
                [ ( "name", E.string "Streaming" )
                , ( "args", E.null )
                ]

        Configuring mStats ->
            E.object
                [ ( "name", E.string "Configuring" )
                , ( "args"
                  , case mStats of
                        Nothing ->
                            E.null

                        Just stats ->
                            statsEncoder stats
                  )
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


encode : Model -> E.Value
encode model =
    E.object
        [ ( "modelState", encodeModelState model.modelState )
        , ( "modelConfig", statsConfigEncoder model.modelConfig )
        , ( "streamState", streamStateEncoder model.streamState )
        , ( "lastMessage"
          , case model.lastMessage of
                Nothing ->
                    E.null

                Just msg ->
                    messageEncoder msg
          )
        , ( "disabledStats", E.int model.disabledStats )
        , ( "stagePage", E.int model.stagePage )
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


preModelStateToState : PreModelState -> D.Decoder StatsStatus
preModelStateToState preModelState =
    case preModelState.name of
        "Waiting" ->
            D.succeed Waiting

        "Streaming" ->
            D.succeed Streaming

        "Configuring" ->
            D.field "args" (D.nullable statsDecoder)
                |> D.andThen (Configuring >> D.succeed)

        "Done" ->
            D.field "args" statsDecoder
                |> D.andThen (Done >> D.succeed)

        other ->
            D.fail <| "Unsupported model state: " ++ other


decode : D.Decoder Model
decode =
    D.map6 Model
        (D.field "modelState"
            (decodePreModelState
                |> D.andThen preModelStateToState
            )
        )
        (D.field "modelConfig" statsConfigDecoder)
        (D.field "streamState" streamStateDecoder)
        (D.field "lastMessage" <| D.nullable messageDecoder)
        (D.field "disabledStats" D.int)
        (D.field "stagePage" D.int)


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


defaultStatsConfig : StatsConfig
defaultStatsConfig =
    { totalDamage = True
    , neutralWins = True
    , counterHits = True
    , avgApm = True
    , avgOpeningsPerKill = True
    , avgDamagePerOpening = True
    , avgKillPercent = True
    , favoriteMove = True
    , favoriteKillMove = True
    , setCountAndWinner = True
    , stages = True
    }



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    messageReceiver Recv



-- Http.track "upload" GotProgress
-- main


init : E.Value -> ( Model, Cmd Msg )
init flags =
    case D.decodeValue decode flags of
        Err err ->
            ( { modelState = Waiting
              , modelConfig = defaultStatsConfig
              , streamState =
                    { players = Array.empty
                    , endGames = []
                    , currentPcts = Array.empty
                    , currentChars = Array.empty
                    }
              , lastMessage = Nothing
              , disabledStats = 0
              , stagePage = 0
              }
            , log (D.errorToString err)
            )

        Ok model ->
            ( model, Cmd.none )


main =
    Browser.element
        { init = init
        , update = updateWithStorage
        , view = view
        , subscriptions = subscriptions
        }
