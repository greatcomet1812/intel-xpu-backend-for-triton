// RUN: triton-opt %s -triton-raise-block-pointer -canonicalize | FileCheck %s

module {
  tt.func @kernel(
  %arg0 : !tt.ptr<bf16>,
  %arg1 : !tt.ptr<bf16>,
  %arg2 : i32
  )
  {
  %0 = tt.make_range {end = 4 : i32, start = 0 : i32}:tensor<4xi32>
  // offset = 0, size = 4, stride = 1
  %1 = tt.expand_dims %0 {axis = 1 : i32} : tensor<4xi32> -> tensor<4x1xi32>
  // offset = [0,0], size = [4,1], stride = [1,0]
  %2 = tt.broadcast %1 : tensor<4x1xi32> -> tensor<4x256xi32>
  // offset = [0,0], size = [4,256], stride = [1,0]
  %arg2splat = tt.splat %arg2 : i32 -> tensor<4x256xi32>
  %offset2 = arith.addi %2, %arg2splat : tensor<4x256xi32>
  // offset = [%arg2,0], size = [4,256], stride = [1,0]
  %3 = tt.make_range {end = 256 : i32, start = 0 : i32}:tensor<256xi32>
  // offset = 0, size = 256, stride = 1
  %4 = tt.expand_dims %3 {axis = 0 : i32} : tensor<256xi32> -> tensor<1x256xi32>
  // offset = [0,0], size = [1,256], stride = [0,1]
  %5 = tt.broadcast %4 : tensor<1x256xi32> -> tensor<4x256xi32>
  // offset = [0,0], size = [4,256], stride = [0,1]
  %c6 = arith.constant 6 : i32
  %splat6 = tt.splat %c6 : i32 -> tensor<4x256xi32>
  %scale5 = arith.muli %5, %splat6 : tensor<4x256xi32>
  // offset = [0,0], size = [4,256], stride = [0,6]
  %7 = arith.addi %offset2, %scale5: tensor<4x256xi32>
  // offset = [%arg2, 0], size = [4, 256], stride = [1, 6]
  %8 = tt.splat %arg0 : !tt.ptr<bf16> -> tensor<4x256x!tt.ptr<bf16>>
  %9 = tt.addptr %8, %7 : tensor<4x256x!tt.ptr<bf16>>, tensor<4x256xi32>
  // source: arg0, offset = [%arg2, 0], size = [4, 256], stride = [1, 6]
  %10 = tt.splat %arg1 : !tt.ptr<bf16> -> tensor<4x256x!tt.ptr<bf16>>
  %11 = tt.addptr %10, %7 : tensor<4x256x!tt.ptr<bf16>>, tensor<4x256xi32>
  // source: arg1, offset = [%arg2, 0], size = [4, 256], stride = [1, 6]
  %12 = tt.load %9 {cache = 1 : i32, evict = 1 : i32, isVolatile = false}: tensor<4x256x!tt.ptr<bf16>>
  tt.store %11, %12 : tensor<4x256x!tt.ptr<bf16>>
  tt.return
  }
}

// CHECK:         tt.func @kernel([[PARAM_0_:%.+]]: !tt.ptr<bf16>, [[PARAM_1_:%.+]]: !tt.ptr<bf16>, [[PARAM_2_:%.+]]: i32) {
// CHECK-DAG:       [[CST_0_i64:%.+]] = arith.constant 0 : i64
// CHECK-DAG:       [[CST_0_i32:%.+]] = arith.constant 0 : i32
// CHECK-DAG:       [[CST_1_i64:%.+]] = arith.constant 1 : i64
// CHECK-DAG:       [[CST_6_i64:%.+]] = arith.constant 6 : i64
// CHECK-DAG:       [[VAR_0_:%.+]] = tt.make_tensor_ptr [[PARAM_0_]], {{\[}}[[CST_0_i64]], [[CST_0_i64]]], {{\[}}[[CST_1_i64]], [[CST_6_i64]]], {{\[}}[[PARAM_2_]], [[CST_0_i32]]] {{.*}} : <tensor<4x256xbf16>>
// CHECK-DAG:       [[VAR_1_:%.+]] = tt.make_tensor_ptr [[PARAM_1_]], {{\[}}[[CST_0_i64]], [[CST_0_i64]]], {{\[}}[[CST_1_i64]], [[CST_6_i64]]], {{\[}}[[PARAM_2_]], [[CST_0_i32]]] {{.*}} : <tensor<4x256xbf16>>
// CHECK-DAG:       [[VAR_2_:%.+]] = tt.load [[VAR_0_]] : !tt.ptr<tensor<4x256xbf16>>
// CHECK:           tt.store [[VAR_1_]], [[VAR_2_]] : !tt.ptr<tensor<4x256xbf16>>
// CHECK:           tt.return
// CHECK:         }
