module System.Monopati.Posix.Core
	( Points (..), Origin (..), Dummy (..), Path, Outline (..), Parent (..)
	, Absolute, Current, Homeward, Previous, Relative
    , Incompleted, Certain, Parental) where

import "base" Control.Applicative (pure)
import "base" Data.Eq (Eq)
import "base" Data.Foldable (Foldable (foldr))
import "base" Data.Function ((.), ($), (&), flip)
import "base" Data.Kind (Constraint, Type)
import "base" Data.List (init, replicate, reverse)
import "base" Data.Maybe (Maybe (Just, Nothing), maybe)
import "base" Data.Semigroup (Semigroup ((<>)))
import "base" Data.String (String)
import "base" Prelude (fromEnum)
import "base" Text.Read (Read (readsPrec))
import "base" Text.Show (Show (show))
import "free" Control.Comonad.Cofree (Cofree ((:<)))
import "peano" Data.Peano (Peano)
import "split" Data.List.Split (endBy, splitOn)

-- | What the path points to?
data Points = Directory | File

-- | What is the beginning of the path?
data Origin
	= Root -- ^ Starting point for absolute path
	| Now -- ^ Indication of current working directory
	| Home -- ^ Indication of home directory
	| Early -- ^ Indication of previous current working directory
	| Vague -- ^ For uncertain relative path

-- | Dummy type needed only for beautiful type declarations
data Dummy = For | To

-- | Path is non-empty sequence of folders or file (in the end)
type Path = Cofree Maybe String

-- | The internal type of path representation
newtype Outline (origin :: Origin) (points :: Points) =
	Outline { outline :: Path } deriving Eq

show_foldaway, show_foldaway_reverse :: Outline origin points -> String
show_foldaway = foldr (\x acc -> x <> "/" <> acc) "" . outline
show_foldaway_reverse = foldr (\x acc -> acc <> "/" <> x) "" . outline

generate_parental_string :: Peano -> String
generate_parental_string n = foldr (<>) "" $ replicate (fromEnum n) "../"

type family Absolute (path :: Type) (to :: Dummy) (points :: Points) :: Type where
	Absolute Path To points = Outline Root points

instance Show (Outline Root Directory) where show = flip (<>) "/" . show_foldaway_reverse
instance Show (Outline Root File) where show = show_foldaway_reverse

instance Read (Outline Root Directory) where
	readsPrec _ ('/':[]) = []
	readsPrec _ ('/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(reverse $ endBy "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

instance Read (Outline Root File) where
	readsPrec _ ('/':[]) = []
	readsPrec _ ('/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(reverse $ splitOn "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

type family Current (path :: Type) (to :: Dummy) (points :: Points) :: Type where
	Current Path To points = Outline Now points

instance Show (Outline Now Directory) where show = (<>) "./" . show_foldaway
instance Show (Outline Now File) where show = (<>) "./" . init . show_foldaway

instance Read (Outline Now Directory) where
	readsPrec _ ('.':'/':[]) = []
	readsPrec _ ('.':'/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(endBy "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

instance Read (Outline Now File) where
	readsPrec _ ('.':'/':[]) = []
	readsPrec _ ('.':'/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(splitOn "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

type family Homeward (path :: Type) (to :: Dummy) (points :: Points) :: Type where
	Homeward Path To points = Outline Home points

instance Show (Outline Home Directory) where show = (<>) "~/" . show_foldaway
instance Show (Outline Home File) where show = (<>) "~/" . init . show_foldaway

instance Read (Outline Home Directory) where
	readsPrec _ ('~':'/':[]) = []
	readsPrec _ ('~':'/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(endBy "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

instance Read (Outline Home File) where
	readsPrec _ ('~':'/':[]) = []
	readsPrec _ ('~':'/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(splitOn "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

type family Previous (path :: Type) (to :: Dummy) (points :: Points) :: Type where
	Previous Path To points = Outline Early points

instance Show (Outline Early Directory) where show = (<>) "-/" . show_foldaway
instance Show (Outline Early File) where show = (<>) "-/" . init . show_foldaway

instance Read (Outline Early Directory) where
	readsPrec _ ('-':'/':[]) = []
	readsPrec _ ('-':'/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(endBy "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

instance Read (Outline Early File) where
	readsPrec _ ('-':'/':[]) = []
	readsPrec _ ('-':'/':rest) = foldr (\el -> Just . (:<) el) Nothing
		(splitOn "/" rest) & maybe [] (pure . (,[]) . Outline)
	readsPrec _ _ = []

type family Relative (path :: Type) (to :: Dummy) (points :: Points) :: Type where
	Relative Path To points = Outline Vague points

instance Show (Outline Vague Directory) where show = show_foldaway
instance Show (Outline Vague File) where show = init . show_foldaway

instance Read (Outline Vague Directory) where
	readsPrec _ [] = []
	readsPrec _ rest = foldr (\el -> Just . (:<) el) Nothing
		(endBy "/" rest) & maybe [] (pure . (,[]) . Outline)

instance Read (Outline Vague File) where
	readsPrec _ [] = []
	readsPrec _ rest = foldr (\el -> Just . (:<) el) Nothing
		(splitOn "/" rest) & maybe [] (pure . (,[]) . Outline)

type family Incompleted (origin :: Origin) :: Constraint where
	Incompleted Now = ()
	Incompleted Home = ()
	Incompleted Early = ()
	Incompleted Vague = ()

type family Certain (origin :: Origin) :: Constraint where
	Certain Root = ()
	Certain Now = ()
	Certain Home = ()
	Certain Early = ()

data Parent origin points = Incompleted origin =>
	Parent Peano (Outline origin points)

type family Parental (for :: Dummy) (outline :: Type) :: Type where
	Parental For (Outline origin points) = Parent origin points

instance Show (Parent Now Directory) where
	show (Parent n raw) = "./" <> generate_parental_string n <> show_foldaway raw

instance Show (Parent Now File) where
	show (Parent n raw) = "./" <> generate_parental_string n <> (init $ show_foldaway raw)

instance Show (Parent Home Directory) where
	show (Parent n raw) = "~/" <> generate_parental_string n <> show_foldaway raw

instance Show (Parent Home File) where
	show (Parent n raw) = "~/" <> generate_parental_string n <> (init $ show_foldaway raw)

instance Show (Parent Early Directory) where
	show (Parent n raw) = "-/" <> generate_parental_string n <> show_foldaway raw

instance Show (Parent Early File) where
	show (Parent n raw) = "-/" <> generate_parental_string n <> (init $ show_foldaway raw)

instance Show (Parent Vague Directory) where
	show (Parent n raw) = generate_parental_string n <> show_foldaway raw

instance Show (Parent Vague File) where
	show (Parent n raw) = generate_parental_string n <> (init $ show_foldaway raw)
