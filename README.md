# redis-lean

> ⚠️ **Warning**: this is work in progress, it is still incomplete and it ~~may~~ will contain errors

[Redis](https://redis.io/) is an outstanding database, and enabling the [Lean](https://lean-lang.org/) ecosystem to interact with it could unlock many exciting possibilities.
The versatility and efficiency of *Redis* make it an ideal candidate for storing Lean’s complex terms and types
(including maybe internal structures such as proof states).

This repo hosts:

🔧 a minimal *Redis* **[Client](RedisLean/README.md)**: client library for *Lean* built around [hiredis](https://github.com/redis/hiredis) (a C library), improved with a typed monadic interface (somehow inspired by Haskell's [Hedis](https://hackage.haskell.org/package/hedis) library)

📖 a minimal *Redis* **[Model](RedisModel/README.md)**: tentative formal specs for the very core *Redis* operations (an abstract formal model of *Redis* as a key-value store) meant to be used in a theorem proving framework. The model is minimal and does not encompass the very rich set of *Redis* features (key expirations, non-bytearray data types, pubsub engine and much more)

📝 some **[Remarks](RedisLean/remarks.md)** about Redis

Please remark:

- client **[wrapping](hiredis/README.md)** just *hiredis* synchronous APIs
- *Redis* is huge and not all the commands have been wrapped and inserted into the high-level interface (anyway, a generic low-level way to send arbitrary commands is available)
- no SSL/TLS support, no password support
- no full support for some command options (for example: the basic SET command has also a GET option which is not covered)
- testing is still to be developed (also in relation
to the abstract model)
- this repo include some simple **[examples](Examples/README.md)** about how to use the client lib

Please note that, despite the presence of this minimal model of Redis, the true potential of Lean remains largely untapped in this repository. At present, Lean is being used primarily as a functional programming language—similar to Haskell (though arguably an even more expressive and elegant one). However, its far greater strength lies in its capabilities as an interactive theorem prover. This project does not yet explore those dimensions: no formal proofs of correctness, consistency, or deeper properties of the model have been attempted here. The current work should therefore be seen as a foundation—a minimal but precise specification of Redis’s core operations—on top of which richer formal reasoning and verification could eventually be developed.

## Use of coding assistants

**Claude Sonnet 4** was helpful in many ways, particularly with C wrappers and READMEs. Most of the time, however, both the overall style and the specific solutions were drafted or refined manually.
Coding assistants also proved useful for Lean code (mainly in examples) though in those cases the majority of the code was either written directly by hand or substantially modified.
Perhaps the code would have been cleaner with more extensive use of assistants, but my main goal was to learn some Lean
(so while the code is maybe a bit clumsy, I like to think I learned something in the process).

For now, in my opinion, the main advantage of using a coding assistant isn’t so much that you don’t have to code anymore, but rather that even a modest 20% of help scales well with the ambition of the project. You can think of more ambitious ideas and actually build larger things, because that support you do get really scales.

However, both **Claude Sonnet 4** and **GPT-5** were invaluable for brainstorming, but in any case, all code has been manually reviewed. So, any remaining errors are therefore entirely the author’s responsibility.
## License

Apache License 2.0 - see LICENSE file for details.
