---
layout: post
bootstrap: true
title: What I've learned about Nostr by improving ZapThreads and how do we <span class='no-wrap'>improve NIP-07 UX</span>
feature-img: "assets/img/improved-zapthreads-feature.webp"
thumbnail: "assets/img/improved-zapthreads-thumbnail.webp"
date: 2024-08-11 23:20:00 +0000
tags: [nostr]
nostr:
  comments: note1rzd7zy6x5wpm7gxtekgflmh8yt7twadddcu0ldp7hxdfe9d6aycqkll2gw
  relax_filters: true
---

I've been playing with Nostr for a couple of months now and have made [**some improvements**](https://github.com/codonaft/zapthreads-codonaft#readme) in [ZapThreads](https://zapthreads.dev/).
I'm happy to finally integrate it here!

Feel free to try it in the comments section. It's still experimental, however you can integrate it on your website as well.

Here's what I've learned and how we could improve NIP-07 browser extensions IMO.
<!--more-->

## NIP-11 Relay Info
It's currently misconfigured on almost all existing public relays 😿
- there's no way to check whether relay actually receives [{% include span_with_tooltip.html large="true" body="reactions" tooltip="Votes are also reactions in Nostr. Since they are disabled in many relays—votes appear to behave <span class='no-wrap'>buggy to end-users.</span>" %}](https://github.com/rnostr/rnostr/pull/16) or not
- for now we're damned to [violate](https://github.com/nostr-protocol/nips/issues/1319#issuecomment-2181164676) relay rules in some scenarios.

Fetching the info currently forces us to open an additional connection per relay, which affects initial warm-up time.

Currently, I'm finding NIP-11 unusable for my scenarios.
If you want to integrate my ZapThreads [fork](https://github.com/codonaft/zapthreads-codonaft#readme)—consider disabling `relayInfo` for now.

## NIP-07 Extensions Lack Sessions
The browser extensions work fine in a simple scenario, but if you want multiple accounts and session persistence—expect surprises.

From a web app dev perspective, I found that it's tricky to properly handle Nostr sessions.
It's easy to accidentally make your website trigger unnecessary permission requests.
Some websites already do that, right after the first visit, multiple times in a row.

We shouldn't make frequent API calls that require permissions.
Otherwise normal users will get used to it to that point where they ignore these windows and authorize everything blindly or accidentally.
Others may simply never go back to such websites, thinking that they are malicious or just buggy.

Some websites just keep showing previously logged in user even if I changed it.
That just feels like incorrect behavior.
As end-user I would suspect that making actions from such website would mean accidentally signing events by other user.

For now we have a single [active](https://github.com/diegogurpegui/nos2x-fox/tree/v1.14.0#screenshots) [profile](https://github.com/neilck/aka-extension#readme) for all websites and no way to make permissionless check that currently selected profile has authorized session on the given website or not.

Instead of that, I wish that extension itself could hold all the sessions and assign **user account(s) per website**, so it would be possible to
- use multiple websites with different user accounts simultaneously
- switch between authorized accounts seamlessly for a single website, without affecting other websites.

### Browser Extension as External Signer Client
Auth is still complicated, both for devs and users.
[Many](https://github.com/nostr-protocol/nips/blob/master/07.md) [{% include span_with_tooltip.html body="ways" tooltip="I believe NIP-26 <span class='no-wrap'>is actually deprecated</span>" %}](https://github.com/nostr-protocol/nips/blob/master/26.md) to [do it](https://github.com/nostr-protocol/nips/blob/master/46.md), but sadly only few of them actually [work](https://github.com/fiatjaf/window.nostr.js/issues/8) [properly](https://github.com/fiatjaf/nak/issues/27) (if [at all](https://github.com/toastr-space/keys-band/issues/35)).
That's expected, Nostr is still pretty young.

In web apps I'd prefer to deal with a single NIP-07-like spec and stay away from any concrete auth/sign protocols, because [there are](https://github.com/nostr-protocol/nips/issues/1377) [unobvious](https://github.com/fiatjaf/window.nostr.js/issues/8) [implementation dragons](https://github.com/fiatjaf/nak/issues/27) that web app developer is not interested to deal with.

IMO better approach would be isolation of the NIP-46 bunker connection magic in the extension.
This would also enable possibility to extend/replace existing signer connection protocols seamlessly enough for web app devs and users.

### Single Standard Auth Popup
It'd be nice if NIP-07 provided [something like](https://github.com/nostr-protocol/nips/issues/1421) **permissionless** `async getAuthorizedMethods(): { getPublicKey: boolean, getRelays: boolean, ... }` that returns the fact that user has selected account with certain authorized methods on a given website.

We could call `getAuthorizedMethods` on the page initialization (or poll it periodically):
- if `getPublicKey` is `false`—we can show that no user currently logged in
- if `getPublicKey` and `getRelays` are `true`—we can definitely show what user is currently logged in, without any permission requests annoyance.

Now suppose we've pressed a Login button in our web app.
That means that at least `getPublicKey` is currently `false` but we've called `getPublicKey()` anyway.
In this case imagine that `getPublicKey()` triggers a
{% include span_with_tooltip.html body="little unobtrusive" tooltip="Something that doesn't affect current user/page interaction. Not sure whether it's possible at all." %}
auth popup in the corner:

<img src="/assets/img/possible-nostr-login-browser-extension.svg" alt="Possible Nostr Login Browser Extension" style="width: 100%;">

Something similar to what [wnj](https://git.njump.me/wnj) does right now, but without possibility to access input fields from the website (and ideally without affecting page layout).

Such extension could create various kinds of sessions:
- one-time/non-persistent/pseudoanonymous
- persistent and time-limited
- persistent and endless.

I'd also feel comfortable if such extension would rate-limit all unauthorized NIP-07 calls.
NIP-07 could recommend or even require this behavior.

With such design, a website
- would never need to persist any sessions at all
- doesn't even require any Login button on its pages to function
  - just click on the extension and here's your standard Login or Logout button, for the selected user on the current website
- can't and doesn't need to distinguish external signer users from those who are less secured
- will less likely to annoy with unnecessary permission requests.

Most likely this topic was discussed
{% include span_with_tooltip.html body="the past" tooltip="However I didn't find it. I'd be grateful for any links to the related discussions!" %}
and I suspect that I'm naïvely missing some case that breaks this design somewhere,
so your thoughts on all this are very welcome.
