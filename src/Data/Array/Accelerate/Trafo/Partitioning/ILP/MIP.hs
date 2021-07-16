{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans #-} -- Shame on me!

module Data.Array.Accelerate.Trafo.Partitioning.ILP.MIP (
  -- Exports default paths to 6 solvers, as well as an instance to ILPSolver for all of them
  cbc, cplex, glpsol, gurobiCl, lpSolve, scip
  ) where

import Data.Array.Accelerate.Trafo.Partitioning.ILP.Graph (MakesILP)
import qualified Data.Array.Accelerate.Trafo.Partitioning.ILP.Graph as Graph (Var)

import Data.Array.Accelerate.Trafo.Partitioning.ILP.Solver 
import qualified Data.Map as M

import Numeric.Optimization.MIP hiding (Bounds, Constraint, Var, Solution)
import qualified Numeric.Optimization.MIP as MIP
import qualified Numeric.Optimization.MIP.Solver.Base as MIP
import Data.Scientific ( Scientific )
import Data.Bifunctor (bimap)

import Numeric.Optimization.MIP.Solver
    ( cbc, cplex, glpsol, gurobiCl, lpSolve, scip )

instance (MakesILP op, MIP.IsSolver s IO) => ILPSolver s op where
  solve s (ILP dir obj constr bnds) = makeSolution <$> MIP.solve s options problem
    where
      options = MIP.SolveOptions{ MIP.solveTimeLimit   = Nothing
                                , MIP.solveLogger      = putStrLn . ("AccILPSolver says: " ++)
                                , MIP.solveErrorLogger = putStrLn . ("AccILPSolverError: " ++) }

      problem = Problem (Just "AccelerateILP") (mkFun dir $ expr obj) (cons constr) [] [] vartypes (bounds bnds)
      
      mkFun Maximise = ObjectiveFunction (Just "AccelerateObjective") OptMax
      mkFun Minimise = ObjectiveFunction (Just "AccelerateObjective") OptMin

      vartypes = allIntegers bnds -- assuming that all variables have bounds

-- MIP has a Num instance for expressions, but it's scary (because 
-- you can't guarantee linearity with arbitrary multiplications).
-- We use that instance here, knowing that our own Expression can only be linear.
expr :: MakesILP op => Expression op -> MIP.Expr Scientific
expr (Constant i) = fromIntegral i
expr (x :+ y) = expr x + expr y
expr (x :- y) = expr x - expr y
expr (x :* y) = fromIntegral x * varExpr (var y)

cons :: MakesILP op => Constraint op -> [MIP.Constraint Scientific]
cons (x :>= y) = [expr x MIP..>=. expr y]
cons (x :<= y) = [expr x MIP..<=. expr y]
cons (x :== y) = [expr x MIP..==. expr y]

cons (x :&& y) = cons x <> cons y
cons TrueConstraint = mempty

bounds :: MakesILP op => Bounds op -> M.Map MIP.Var (Extended Scientific, Extended Scientific)
bounds (Binary v) = M.singleton (var v) (Finite 0, Finite 1)
bounds (LowerUpper l v u) = M.singleton (var v) (Finite (fromIntegral l), Finite (fromIntegral u))
bounds (x :<> y) = bounds x <> bounds y
bounds NoBounds = mempty

-- make all variables that occur in the bounds have integer type.
allIntegers :: MakesILP op => Bounds op -> M.Map MIP.Var VarType 
allIntegers (Binary v)         = M.singleton (var v) IntegerVariable
allIntegers (LowerUpper _ v _) = M.singleton (var v) IntegerVariable
allIntegers (x :<> y) = allIntegers x <> allIntegers y
allIntegers NoBounds = mempty

-- For MIP, variables are Text-based. This is why Var and BackendVar have Show and Read instances.
var   :: MakesILP op => Graph.Var op -> MIP.Var
var   = toVar . show
unvar :: MakesILP op => MIP.Var -> Graph.Var op
unvar = read . fromVar


makeSolution :: MakesILP op => MIP.Solution Scientific -> Maybe (Solution op)
makeSolution (MIP.Solution StatusOptimal _ m) = Just . M.fromList . map (bimap unvar round) $ M.toList m
makeSolution _ = Nothing
