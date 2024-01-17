module SOAS

import Data.List.Quantifiers
import Data.Singleton
import Data.DPair
import Syntax.WithProof

prefix 4 %%
infixr 3 -|> , ~> , ~:> , -<>, ^
infixl 3 <<<
infixr 4 :-

record (.extension) (types : Type) where
  constructor (:-)
  0 name : String
  ofType : types

data (.Ctx) : (type : Type) -> Type where
  Lin : type.Ctx
  (:<) : (ctx : type.Ctx) -> (namety : type.extension) -> type.Ctx

(.Family), (.SortedFamily) : Type -> Type
type.Family = type.Ctx -> Type
type.SortedFamily = type -> type.Family

data (.varPos) : type.Ctx -> (0 x : String) -> type -> Type
    where [search x]
  Here  : (ctx :< (x :- ty)).varPos x ty
  There : ctx.varPos x ty -> (ctx :< sy).varPos x ty

data (.var) : type.Ctx -> type -> Type where
  (%%) : (0 name : String) -> {auto pos : ctx.varPos name ty} -> ctx.var ty

0
(.name) : ctx.var ty -> String
(%% name).name = name

(.pos) : (v : ctx.var ty) -> ctx.varPos v.name ty
((%% name) {pos}).pos = pos

(.toVar) : (v : ctx.varPos x ty) -> ctx.var ty
pos.toVar {x} = (%% x) {pos}

ThereVar : (v : ctx.var ty) -> (ctx :< ex).var ty
ThereVar v = (%% v.name) {pos = There v.pos}

Var : type.SortedFamily
Var = flip (.var)

0
(-|>) : {type : Type} -> (src,tgt : type.SortedFamily) -> Type
(src -|> tgt) = {ty : type} -> {0 ctx : type.Ctx} ->
  src ty ctx -> tgt ty ctx

(++) : (ctx1,ctx2 : type.Ctx) -> type.Ctx
ctx1 ++ [<] = ctx1
ctx1 ++ (ctx2 :< ty) = (ctx1 ++ ctx2) :< ty

(<<<) : type.SortedFamily -> type.Ctx -> type.SortedFamily
(f <<< ctx0) ty ctx = f ty (ctx ++ ctx0)

(.subst) : {type : Type} -> type.SortedFamily -> type.Ctx -> type.Ctx -> Type
f.subst ctx1 ctx2 = {ty : type} -> ctx1.var ty -> f ty ctx2

0 (.substNamed) : {type : Type} -> type.SortedFamily -> type.Ctx -> type.Ctx -> Type
f.substNamed ctx1 ctx2 = {0 x : String} -> {ty : type} -> ctx1.varPos x ty -> f ty ctx2

(~>) : {type : Type} -> (src, tgt : type.Ctx) -> Type
(~>) = (Var).subst

0 (~:>) : {type : Type} -> (src, tgt : type.Ctx) -> Type
(~:>) = (Var).substNamed

weakl : (ctx1, ctx2 : type.Ctx) -> ctx1 ~> (ctx1 ++ ctx2)
weakl ctx1 [<] x = x
weakl ctx1 (ctx2 :< z) x = ThereVar (weakl ctx1 ctx2 x)

weakrNamed : (ctx1, ctx2 : type.Ctx) -> ctx2 ~:> (ctx1 ++ ctx2)
weakrNamed ctx1 (ctx :< (x :- ty)) Here = (%% x) {pos = Here}
weakrNamed ctx1 (ctx :< sy) (There pos) =
  ThereVar $ weakrNamed ctx1 ctx pos

weakr : (ctx1, ctx2 : type.Ctx) -> ctx2 ~> (ctx1 ++ ctx2)
weakr ctx1 ctx2 ((%% name) {pos}) = weakrNamed ctx1 ctx2 pos

(.copairPos) : (x : type.SortedFamily) -> {ctx2 : type.Ctx} ->
  x.subst ctx1 ctx -> x.subst ctx2 ctx -> x.substNamed (ctx1 ++ ctx2) ctx
x.copairPos {ctx2 = [<]} g1 g2 pos = g1 $ pos.toVar
x.copairPos {ctx2 = (ctx :< (name :- ty))} g1 g2 Here = g2 (Here .toVar)
x.copairPos {ctx2 = (ctx2 :< namety)} g1 g2 (There pos) =
  x.copairPos g1 (g2 . ThereVar) pos

(.copair) : (x : type.SortedFamily) -> {ctx2 : type.Ctx} ->
  x.subst ctx1 ctx -> x.subst ctx2 ctx -> x.subst (ctx1 ++ ctx2) ctx
x.copair g1 g2 v = x.copairPos g1 g2 v.pos

extend : (x : type.SortedFamily) -> {ctx1 : type.Ctx} -> {ty : type} ->
  x ty ctx2 -> x.subst ctx1 ctx2 -> x.subst (ctx1 :< (n :- ty)) ctx2
extend x {ctx2, ty} u theta =
  x.copair {ctx2 = [< n :- ty]} theta workaround -- (\case {Here => x})
    where
      workaround : x.subst [< (n :- ty)] ctx2
      workaround ((%% _) {pos = Here}) = u
      workaround ((%% _) {pos = There _}) impossible

0
(-<>) : (src, tgt : type.SortedFamily) -> type.SortedFamily
(src -<> tgt) ty ctx = {0 ctx' : type.Ctx} -> src ty ctx' ->
  tgt ty (ctx ++ ctx')

0
Nil : type.SortedFamily -> type.SortedFamily
Nil f ty ctx = {0 ctx' : type.Ctx} -> ctx ~> ctx' -> f ty ctx'

-- TODO: (Setoid) coalgebras

0
(^) : (tgt, src : type.SortedFamily) -> type.SortedFamily
(tgt ^ src) ty ctx =
  {0 ctx' : type.Ctx} -> src.subst ctx ctx' -> tgt ty ctx'

hideCtx : {0 a : type.Ctx -> Type} ->
  ((0 ctx : type.Ctx) -> a ctx) -> {ctx : type.Ctx} -> a ctx
hideCtx f {ctx} = f ctx

0
(*) : (derivative, tangent : type.SortedFamily) -> type.SortedFamily
(derivative * tangent) ty ctx =
  (ctx' : type.Ctx ** (derivative ty ctx' , tangent.subst ctx' ctx))

record MonStruct (m : type.SortedFamily) where
  constructor MkSubstMonoidStruct
  var : Var -|> m
  mult : m -|> (m ^ m)

(.sub) : {m : type.SortedFamily} -> {ty,sy : type} -> {ctx : type.Ctx} ->
  (mon : MonStruct m) => m sy (ctx :< (n :- ty)) -> m ty ctx -> m sy ctx
t.sub s = mon.mult t (extend m s mon.var)

(.sub2) : {m : type.SortedFamily} -> {ty1,ty2,sy : type} ->
  {ctx : type.Ctx} ->
  (mon : MonStruct m) => m sy (ctx :< (x :- ty1) :< (x :- ty2)) ->
  m ty1 ctx ->  m ty2 ctx -> m sy ctx
t.sub2 s1 s2 = mon.mult t (extend m s2 (extend m s1 mon.var))

record PointedCoalgStruct (x : type.SortedFamily) where
  constructor MkPointedCoalgStruct
  ren : x -|> [] x
  var : Var -|> x

liftPos : (ctx : type.Ctx) -> (mon : PointedCoalgStruct p) =>
  {ctx2 : type.Ctx} ->
  (p.subst ctx1 ctx2) -> p.substNamed (ctx1 ++ ctx) (ctx2 ++ ctx)
liftPos [<] f x = f x.toVar
liftPos (ctx :< (_ :- _)) f Here = mon.var (Here .toVar)
liftPos (ctx :< namety) f (There pos) = mon.ren (liftPos ctx f pos)
  ThereVar


lift : (ctx : type.Ctx) -> (mon : PointedCoalgStruct p) =>
  {ctx2 : type.Ctx} ->
  (p.subst ctx1 ctx2) -> p.subst (ctx1 ++ ctx) (ctx2 ++ ctx)
lift ctx f v = liftPos ctx f v.pos

0
Strength : (f : type.SortedFamily -> type.SortedFamily) -> Type
Strength f = {0 p,x : type.SortedFamily} -> (mon : PointedCoalgStruct p) =>
  (f (x ^ p)) -|> ((f x) ^ p)

0
(.SortedFunctor) : (type : Type) -> Type
type.SortedFunctor = type.SortedFamily -> type.SortedFamily

0
(.Map) : type.SortedFunctor -> Type
signature.Map
  = {0 a,b : type.SortedFamily} -> (a -|> b) ->
    signature a -|> signature b

record (.MonoidStruct)
         (signature : type.SortedFunctor)
         (x : type.SortedFamily) where
  constructor MkSignatureMonoid
  mon : MonStruct x
  alg : signature x -|> x

record (.MetaAlg)
         (signature : type.SortedFunctor)
         (meta : type.SortedFamily)
         (a : type.SortedFamily) where
  constructor MkMetaAlg
  alg : signature a -|> a
  var : Var -|> a
  mvar : meta -|> (a ^ a)


traverse : {0 p,a : type.SortedFamily} ->
      {0 signature : type.SortedFunctor} ->
      (functoriality : signature.Map) =>
      (str : Strength signature) =>
      (coalg : PointedCoalgStruct p) =>
      (alg : signature a -|> a) ->
      (phi : p -|> a) ->
      (chi : meta -|> (a ^ a)) -> signature.MetaAlg meta (a ^ p)
traverse {p,a} alg phi chi = MkMetaAlg
      { alg = \h,s => alg $ str h s
      , var = \v,s => phi (s v)
      , mvar = \m,e,s => chi m (\v => e v s)
      }

namespace TermDef
 mutual
  {- alas, non obviously strictly positive because we can't tell
     Idris that signature must be strictly positive.

     It will be, though, if we complete the termination project
  -}

  public export
  data Sub : {0 signature : type.SortedFunctor} ->
       type.SortedFamily -> type.Ctx ->
       type.Ctx -> Type where
      Lin :  Sub {type, signature} x [<] ctx
      (:<) : Sub {type, signature} x shape ctx ->
             signature.Term x ty ctx ->
             Sub {type,signature} x (shape :< (n :- ty)) ctx

  public export
  data (.Term) : (signature : type.SortedFunctor) ->
                 type.SortedFamily -> type.SortedFamily where
    Op : {0 signature : type.SortedFunctor} ->
         signature (signature.Term x) ty ctx ->
         signature.Term x ty ctx
    Va : Var ty ctx -> signature.Term x ty ctx
    Me : {0 ctx1, ctx2 : type.Ctx} ->
         {0 signature : type.SortedFunctor} ->
         x ty ctx2 ->
         Sub (signature.Term x) ctx2 ctx1 ->
         signature.Term {type} x ty ctx1

(.MetaCtx) : Type -> Type
type.MetaCtx = SnocList (type.Ctx, type)

(.metaEnv) : type.SortedFamily -> type.MetaCtx -> type.Family
x.metaEnv [<]            ctx = ()
x.metaEnv (mctx :< meta) ctx =
  (x.metaEnv mctx ctx, (x <<< (fst meta)) (snd meta) ctx)

(.envSem) : (0 a : type.SortedFamily) ->
            {0 signature : type.SortedFunctor} ->
            (str : Strength signature) =>
            (functoriality : signature.Map) =>
            (metalg : signature.MetaAlg x a) =>
            {mctx : type.MetaCtx} ->
            (signature.Term x).metaEnv mctx ctx ->
                             a.metaEnv mctx ctx
(.subSem) : (0 a : type.SortedFamily) ->
            {0 x : type.SortedFamily} ->
            {0 signature : type.SortedFunctor} ->
            (functoriality : signature.Map) =>
            (str : Strength signature) =>
            Sub (signature.Term x) ctx1 ctx2  ->
            a.subst ctx1 ctx2
(.sem) : (0 a : type.SortedFamily) ->
         {0 signature : type.SortedFunctor} ->
         (functoriality : signature.Map) =>
         (str : Strength signature) =>
         (metalg : signature.MetaAlg x a) =>
         signature.Term x -|> a

a.envSem {mctx = [<]         } menv = ()
a.envSem {mctx = mctx :< meta} (menv,v) =
      ( a.envSem {signature,x,str,functoriality} menv
      , a.sem {signature,x,str,functoriality} v
      )
a.sem (Op args) = metalg.alg
                 $ functoriality {b = a}
                   (a.sem {signature,x,str,functoriality}) args
a.sem (Va x   ) = MetaAlg.var metalg x
a.sem {ctx = ctx1''} (Me  m env) =
  MetaAlg.mvar metalg m $ (a.subSem {signature,x,str,functoriality} env)

-- Not sure these are useful
data (+) : (signature1, signature2 : type.SortedFunctor) ->
  type.SortedFunctor where
  Lft  :  {signature1, signature2 : type.SortedFunctor} ->
    (op : sig1 x ty ctx) -> (sig1 + sig2) x ty ctx
  Rgt :  {signature1, signature2 : type.SortedFunctor} ->
    (op : sig2 x ty ctx) -> (sig1 + sig2) x ty ctx

sum : (signatures : List $ (String, type.SortedFunctor)) ->
  type.SortedFunctor
(sum signatures) x ty ctx = Any (\(name,sig) => sig x ty ctx) signatures

prod : (signatures : List $ type.SortedFunctor) ->
  type.SortedFunctor
(prod signatures) x ty ctx = All (\sig => sig x ty ctx) signatures

bind : (tys : type.Ctx) -> type.SortedFunctor
bind tys = (<<< tys)

infixr 3 -:>

data TypeSTLC = B | (-:>) TypeSTLC TypeSTLC

data STLC : TypeSTLC .SortedFunctor  where
  App : (f : a (ty1 -:> ty2) ctx) -> (x : a ty1 ctx) -> STLC a ty2 ctx
  Lam : (x : String) ->
        (body : a ty2 (ctx :< (x :- ty1))) ->
        STLC a (ty1 -:> ty2) ctx

foo : STLC .Term Var (B -:> (B -:> B) -:> B) [<]
foo = Op $ Lam "x" $
      Op $ Lam "f" $
      Op $ App (Va $ %% "f")
               (Va $ %% "x")
