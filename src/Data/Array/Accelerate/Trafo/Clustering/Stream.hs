module Data.Array.Accelerate.Trafo.Clustering.Stream where

import Data.Array.Accelerate.AST.Partitioned



-- Emulate the old 'delayed arrays' approach to fusion
streamfusion :: OperationAcc op () a -> PartitionedAcc op () a
streamfusion = undefined
