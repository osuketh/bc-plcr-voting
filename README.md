# First-voter advantage - PLCRVoting based on bonding curve

Partial Lock Commit Reveal Votingをベースとして、より早く投票することにインセンティブを与える機能を加えたコントラクトです。
PLCRVotingでは、CommitステージとRevealステージに分けた投票プロセスが行われます。　　

```requestVotingRights```によってデポジットしたERC20トークンの量に応じてPLCRVotingコントラクト内での投票権が与えられ、Commitステージでその投票権以下のトークン量相当をコミットすることができます。
また、一度コミットした投票はReveal時までロックされるので動かすことはできません。

このコミット量に対し、Bancorの価格決定方式を使ったBonding Curveによって投票先行者が有利になる設計となっています。
  つまり、同量のコミット量に対しより早く投票するほどより多くの議決権が得られます。
（例えば、x軸をtotalSupply、y軸をpriceにとったy=x^2においてより早くmintされたトークンの方が1トークン当たりのpriceが低くなります。）先行者をどのくらい有利にするか決めるパラメーターは、投票開始者が設定することができます。

そして、Revealステージで投票者はコミット時に設定したsecret saltを使うことで自身の調整後のコミット量を投票結果に反映させ、コミットトークンを解放することができます。  
また、コミット中のアクティブなトークン量はアドレスごとにDLL(Doubly-linked list)によってソートされるのでユーザーは同時期に複数の投票にコミットしていても、
「デポジット量から特定の投票における最大コミットトークン数を引いた値」をコントラクトから引き出すことが可能です。

___

PLCRVoting: https://github.com/ConsenSys/PLCRVoting

Bancor Protocol: https://github.com/bancorprotocol/contracts

Bonding Curve: https://github.com/relevant-community/contracts
