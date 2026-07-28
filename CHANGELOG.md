# Changelog

## [1.1.0](https://github.com/thanhnguyen293/WorkNexus/compare/v1.0.0...v1.1.0) (2026-07-28)


### 🚀 Features

* add "assigned/resolved by me" board quick filters ([4731189](https://github.com/thanhnguyen293/WorkNexus/commit/47311897a7a342178d1b47da7853b88765637cae))
* add hidden Talker debug panel ([2e93fa7](https://github.com/thanhnguyen293/WorkNexus/commit/2e93fa79f6c10357d6575e176b9efcb3a082d66e))
* add quick settings popover ([0c464d1](https://github.com/thanhnguyen293/WorkNexus/commit/0c464d10d9edec1d14b41cc0d8269553acad61b7))
* add ZenTao native boards ([3a8b99f](https://github.com/thanhnguyen293/WorkNexus/commit/3a8b99f5dfb7bf261892386857bb97942c07de99))
* attachment viewer, sidebar tree, button system, quick settings ([4f8aaaa](https://github.com/thanhnguyen293/WorkNexus/commit/4f8aaaab8e335ef50984c788ba65fe5da543310f))
* **board:** add a refresh action and always refetch ticket detail on open ([2b43f82](https://github.com/thanhnguyen293/WorkNexus/commit/2b43f828518bd00fa028f2ccc5730d458d7c8d55))
* **board:** keep bugs I opened or resolved in the my-tickets filter ([143ca0a](https://github.com/thanhnguyen293/WorkNexus/commit/143ca0ae3a13650d655ce5667e445be8a2f0cb43))
* **board:** make GitLab/GitHub (and ZenTao bug) boards offline-first ([3042328](https://github.com/thanhnguyen293/WorkNexus/commit/3042328e813b138cd2e673a92f57e3c3c1366e8c))
* bundled SVG provider brand logos ([3926b71](https://github.com/thanhnguyen293/WorkNexus/commit/3926b71e48ef619bbc31a00ac47499c04addb326))
* drag-to-resize sidebar (width persisted) ([3cf647a](https://github.com/thanhnguyen293/WorkNexus/commit/3cf647a1174eb4795c109b2abef54ebf7ac6f197))
* GitHub provider integration (issues + pull requests) ([155c809](https://github.com/thanhnguyen293/WorkNexus/commit/155c809abf3c26ec1cdcacb4dc29e8dd8db29746))
* GitLab provider integration (issues + merge requests) ([fed9ab8](https://github.com/thanhnguyen293/WorkNexus/commit/fed9ab8ffcbd141b9273485500359661fa3be28d))
* hide the Filters button when there's nothing to filter ([721732c](https://github.com/thanhnguyen293/WorkNexus/commit/721732c1044d72f52af9a1b432663e7ddce75fc3))
* image URL resolution, priority labels, external links, and font/translation UI polish ([fcf8251](https://github.com/thanhnguyen293/WorkNexus/commit/fcf8251e5af7e54be5a92ae53d825f4c9113871b))
* improve provider sync and workspace management ([2936cce](https://github.com/thanhnguyen293/WorkNexus/commit/2936cce0e4ca15c45ab4d6d3c5d46b32a96f7295))
* MR/PR reviewers, rebase/update-branch, and structured task detail ([a6b8777](https://github.com/thanhnguyen293/WorkNexus/commit/a6b87772559bb3f27fd1ebc7e61ff1110f62b161))
* pin GitHub/GitLab projects + "My PRs/MRs" in the sidebar ([e85e615](https://github.com/thanhnguyen293/WorkNexus/commit/e85e615447cff0d412113547cb62ed420e76c057))
* provider labels as colored chips ([bd45920](https://github.com/thanhnguyen293/WorkNexus/commit/bd459201e45660827679c4a44025b071023bd405))
* scope-aware board filters ([8a6f9b3](https://github.com/thanhnguyen293/WorkNexus/commit/8a6f9b3843f1d33971f8177f9722d566f78caef5))
* show typed ZenTao detail metadata ([b493cee](https://github.com/thanhnguyen293/WorkNexus/commit/b493cee241b6156c5b629956717091c28c4b3207))
* sync ZenTao product bug boards ([b707ad8](https://github.com/thanhnguyen293/WorkNexus/commit/b707ad803236642b0ae2ed052304b72bc765faa8))
* **task-detail:** keep MR/PR tab state alive across switches ([39328f0](https://github.com/thanhnguyen293/WorkNexus/commit/39328f0f6a3ebd23f135cb51057ba31533e01b5b))
* **task-detail:** move Commits + Changed files onto their own tabs ([ba1a7d7](https://github.com/thanhnguyen293/WorkNexus/commit/ba1a7d77986f934010e512c53b928ec23ed84b34))
* **task-detail:** per-provider detail panels (GitLab MR + GitHub PR two-pane) ([efda1c6](https://github.com/thanhnguyen293/WorkNexus/commit/efda1c6e2f0b45dcbe9d1c44ceeb56da883c2b53))
* **task-detail:** show real Commits + Changed files on MR/PR detail ([1e24991](https://github.com/thanhnguyen293/WorkNexus/commit/1e24991cbb1825090d73220281bce25f4a58cc5e))
* user search in reviewers dialog, themed workspace dropdown, macOS CI fix ([4e02be6](https://github.com/thanhnguyen293/WorkNexus/commit/4e02be6f2a2877710e3f61ee388893ca13920e41))
* wire up the "My PRs/MRs" board ([d7a94d1](https://github.com/thanhnguyen293/WorkNexus/commit/d7a94d1bfa85ecdaab68d0b791d1688a310e4dcc))
* ZenTao bug board browse-type tabs (server-driven) ([81b8c77](https://github.com/thanhnguyen293/WorkNexus/commit/81b8c7754f0370168194cfd87b94ad7746eafa3c))
* ZenTao task boards, GetIt+injectable DI, data-derived filters ([7645437](https://github.com/thanhnguyen293/WorkNexus/commit/7645437927d79532daa35a8d0ba807b52880e449))


### 🐛 Bug Fixes

* **agents:** resolve and spawn agent CLIs on Windows ([cb66dae](https://github.com/thanhnguyen293/WorkNexus/commit/cb66dae233840233b8e3be1efe39066a91995446))
* clean quick settings analyzer hygiene ([43ff038](https://github.com/thanhnguyen293/WorkNexus/commit/43ff0386611f8383056212b549e717962e9b3944))
* constrain quick settings popover height ([f2ac479](https://github.com/thanhnguyen293/WorkNexus/commit/f2ac4798c924e297d1e986fe494ea6bef89124de))
* **db:** make column-add migrations idempotent ([b48d2cd](https://github.com/thanhnguyen293/WorkNexus/commit/b48d2cd2e69ef4557350bda5c7921449f9047a25))
* inline-asset resolution, GitLab activity notes, and token-page path ([17948ae](https://github.com/thanhnguyen293/WorkNexus/commit/17948ae0ed0029432fef08570b317d9ca2f8d760))
* **perf:** bound runaway HTTP-logger, image, and attachment caches ([196d150](https://github.com/thanhnguyen293/WorkNexus/commit/196d150b900f30d033bf5f9ea68032a1a448ec01))
* ZenTao bug activate — surface REST failures, assign reopen to actor ([35233e3](https://github.com/thanhnguyen293/WorkNexus/commit/35233e313e5d350819242fc8516a8bcc6a366ff3))


### ♻️ Refactoring

* move appearance settings out of integrations ([bc651cd](https://github.com/thanhnguyen293/WorkNexus/commit/bc651cd4fa9754ce9e6b3b3b56b12bcb682729a1))


### 📝 Documentation

* design quick settings popover ([6805c95](https://github.com/thanhnguyen293/WorkNexus/commit/6805c95a9603c60e709fea08bf1c9429dd18b905))
* refine quick settings visual design ([cd1b143](https://github.com/thanhnguyen293/WorkNexus/commit/cd1b1432b13154ebc069d8062eb473d548bce9a4))
* restructure the English and Vietnamese READMEs ([46132e9](https://github.com/thanhnguyen293/WorkNexus/commit/46132e9b0d00a652154f335155a487d8cc1956ab))
