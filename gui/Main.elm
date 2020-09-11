module Main exposing (..)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)

-- model

type alias Model =
    { dir : String
    }

-- update

type Msg
    = DirChange String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DirChange dir ->
            ( { model | dir = dir }
            , Cmd.none
            )

-- view
view : Model -> Html Msg
view model =
    Element.layout [ Background.color black
                   ] <|
    row [ centerX
        , centerY
        , spacing 3
        ]
        [ inputElement DirChange model.dir
        ]

-- elements
black = rgb255 0 0 0
white = rgb255 255 255 255
grey = rgb255 25 25 25
red = rgb255 255 0 0

inputElement msg modelField =
    Input.text [ Background.color grey
               , Element.focused [ Background.color grey
                                 ]
               , Font.color white
               , Font.extraBold
               , Font.center
               , Font.family [ Font.external
                                   { name = "Roboto"
                                   , url = "https://fonts.googleapis.com/css?family=Roboto"
                                     }
                             , Font.sansSerif
                             ]
               , Font.size 24
               , Border.color white
               , Border.rounded 5
               , Border.width 2
               ]
    { onChange = msg
    , text = modelField
    , placeholder = Nothing
    , label = Input.labelHidden ""
    }

-- subscriptions
subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none

-- main

init : () -> ( Model, Cmd Msg )
init _ =
    ( { dir = "" }
    , Cmd.none
    )

main = Browser.element
       { init = init
       , update = update
       , view = view
       , subscriptions = subscriptions
       }
