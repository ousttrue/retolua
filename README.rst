-------
retolua
-------
tolua++の改造版です。
基本的な処理は同様ですが、コードの構造を変更しました。
あと、一部機能を端折ってます。

tolua++と同じくMITライセンス

本家と違うところ
----------------
- tolua++.exeに埋め込まずにluaスクリプトのまま運用する。ビルド無用(しかし、windowsだとcygwinとかmsys必要)
- c++ヘッダのパースとコード生成を分離した
- std::vectorの自動関数生成(size, operator[], foreachi)

捨てた/未確認の機能
-------------------
- script埋め込み
- alias機能(@)
- template classの継承サポート

予定
----
- std::shared_ptrをなんとかしたい

