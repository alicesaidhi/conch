local ast = require "@self/ast"
local parse = require "@self/parse"
local visit = require "@self/visit"

export type Visitor<State> = visit.Visitor<State>

export type TokenKind = ast.TokenKind
export type Token<T = TokenKind> = ast.Token<T>

export type BinaryOperator = ast.BinaryOperator
export type UnaryOperator = ast.UnaryOperator
export type TokenKindRest = ast.TokenKindRest
export type TokenKindText = ast.TokenKindText

export type Separated<T> = ast.Separated<T>
export type Delimited<L, V, R> = ast.Delimited<L, V, R>

export type FunctionBody = ast.FunctionBody

export type ExpressionNil = ast.ExpressionNil
export type ExpressionBoolean = ast.ExpressionBoolean
export type ExpressionNumber = ast.ExpressionNumber
export type ExpressionBinary = ast.ExpressionBinary
export type ExpressionString = ast.ExpressionString
export type ExpressionLambda = ast.ExpressionLambda
export type ExpressionVector = ast.ExpressionVector
export type ExpressionUnary = ast.ExpressionUnary
export type ExpressionEvaluate = ast.ExpressionEvaluate
export type ExpressionCommand = ast.ExpressionCommand
export type SimpleExpression = ast.SimpleExpression
export type Expression = ast.Expression
export type Command = ast.Command
export type ExpressionTable = ast.ExpressionTable

export type VarRootGlobal = ast.VarRootGlobal
export type VarRootVariable = ast.VarRootVariable
export type VarRootParen = ast.VarRootParen
export type VarRoot = ast.VarRoot
export type VarSuffixNameIndex = ast.VarSuffixNameIndex
export type VarSuffixExpressionIndex = ast.VarSuffixExpressionIndex
export type VarSuffix = ast.VarSuffix
export type Var = ast.Var

export type TableFieldNameKey = ast.TableFieldNameKey
export type TableFieldExpressionKey = ast.TableFieldExpressionKey
export type TableFieldNoKey = ast.TableFieldNoKey
export type TableField = ast.TableField

export type Continue = ast.Continue
export type Break = ast.Break
export type Return = ast.Return
export type LastStatement = ast.LastStatement

export type IfBranch = ast.IfBranch
export type ElseIfBranch = ast.ElseIfBranch
export type ElseBranch = ast.ElseBranch

export type Assign = ast.Assign
export type If = ast.If
export type While = ast.While
export type For = ast.For
export type Statement = ast.Statement

export type Block = ast.Block
export type Ast = ast.Ast

export type Issue = parse.Issue
export type Output = parse.Output

return {
	parse = parse,
	visit = visit,
}
