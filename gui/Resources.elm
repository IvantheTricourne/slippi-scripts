module Resources exposing
    ( charIconPath
    , charImgPath
    , fourStockCharIconPath
    , smashLogo
    , stageImgPath
    , winnerSagaIcon
    )

import Types exposing (Character)



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


winnerSagaIcon : String -> { src : String, description : String }
winnerSagaIcon sagaIconName =
    { src = "rsrc/Characters/Saga Icons/" ++ sagaIconName ++ "G.png"
    , description = "Logo for set winner"
    }


smashLogo : { src : String, description : String }
smashLogo =
    { src = "rsrc/Characters/Saga Icons/Smash.png"
    , description = "Smash Logo Button"
    }
