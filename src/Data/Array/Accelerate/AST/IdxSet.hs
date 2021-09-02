{-# LANGUAGE EmptyCase           #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeOperators       #-}
{-# OPTIONS_HADDOCK hide #-}
-- |
-- Module      : Data.Array.Accelerate.AST.IdxSet
-- Copyright   : [2008..2020] The Accelerate Team
-- License     : BSD3
--
-- Maintainer  : Trevor L. McDonell <trevor.mcdonell@gmail.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Data.Array.Accelerate.AST.IdxSet (
  IdxSet,
  member, varMember, intersect, union, insert, insertVar, skip,
  push, empty, drop, drop', fromList, fromVarList,
  singleton, singletonVar,
) where

import Prelude hiding (drop)

import Data.Array.Accelerate.AST.Idx
import Data.Array.Accelerate.AST.Var
import Data.Array.Accelerate.AST.Environment hiding ( push )
import Data.Array.Accelerate.AST.LeftHandSide
import Data.Maybe

newtype IdxSet env = IdxSet { unIdxSet :: PartialEnv Present env }

data Present a = Present

member :: Idx env t -> IdxSet env -> Bool
member idx (IdxSet set) = isJust $ prjPartial idx set

varMember :: Var s env t -> IdxSet env -> Bool
varMember (Var _ idx) = member idx

intersect :: IdxSet env -> IdxSet env -> IdxSet env
intersect (IdxSet a) (IdxSet b) = IdxSet $ intersectPartialEnv (\_ _ -> Present) a b

union :: IdxSet env -> IdxSet env -> IdxSet env
union (IdxSet a) (IdxSet b) = IdxSet $ unionPartialEnv (\_ _ -> Present) a b

insert :: Idx env t -> IdxSet env -> IdxSet env
insert idx (IdxSet a) = IdxSet $ partialUpdate Present idx a

insertVar :: Var s env t -> IdxSet env -> IdxSet env
insertVar (Var _ idx) = insert idx

skip :: IdxSet env -> IdxSet (env, t)
skip = IdxSet . PNone . unIdxSet

push :: IdxSet env -> IdxSet (env, t)
push = IdxSet . flip PPush Present . unIdxSet

empty :: IdxSet env
empty = IdxSet PEnd

drop :: IdxSet (env, t) -> IdxSet env
drop = IdxSet . partialEnvTail . unIdxSet

drop' :: LeftHandSide s t env env' -> IdxSet env' -> IdxSet env
drop' (LeftHandSidePair lhs1 lhs2) = drop' lhs1 . drop' lhs2
drop' (LeftHandSideWildcard _)     = id
drop' (LeftHandSideSingle _)       = drop

toList :: IdxSet env -> [Exists (Idx env)]
toList = map (\(EnvBinding idx _) -> Exists idx) . partialEnvToList . unIdxSet

fromList :: [Exists (Idx env)] -> IdxSet env
fromList = IdxSet . partialEnvFromList (\_ _ -> Present) . map (\(Exists idx) -> EnvBinding idx Present)

fromVarList :: [Exists (Var s env)] -> IdxSet env
fromVarList = fromList . map (\(Exists (Var _ idx)) -> Exists idx)

singleton :: Idx env t -> IdxSet env
singleton idx = IdxSet $ partialEnvSingleton idx Present

singletonVar :: Var s env t -> IdxSet env
singletonVar (Var _ idx) = singleton idx
