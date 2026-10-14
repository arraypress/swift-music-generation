//
//  YuE2Licence.swift
//  YuE2Music
//
//  Created by David Sherlock on 2026.
//
//  YuE2's weights are not open source: CC BY-NC 4.0, plus the licensors'
//  2026-09-16 permission for individual creators (monetising outputs is fine
//  for a person; commercial use of the weights by a company is not). The
//  engine refuses to start unless a program names the licence version, so
//  nothing runs YuE2 without someone having agreed.
//

import Foundation

/// The terms YuE2 runs under, and the version string the engine must be handed.
public enum YuE2Licence {

    /// The licence version; ``YuE2Engine`` refuses to start unless this is passed to it.
    public static let version = "CC BY-NC 4.0 + YuE2 individual creator permission (2026-09-16)"

    /// The CC BY-NC 4.0 legal code.
    public static let url = URL(string: "https://creativecommons.org/licenses/by-nc/4.0/legalcode")!

    /// Where the licensors publish the weights' terms with the individual-creator permission.
    public static let modelLicenceURL = URL(string:
        "https://github.com/multimodal-art-projection/YuE/blob/1647252d68b70cbead046ffd3f7caf036dde47ee/MODEL_LICENSE")!

    /// The terms in plain words.
    public static let summary = """
        YuE2-3B, YuE2-Vae and YuE2-Vae-legacy (Multimodal Art Projection, m-a-p) are licensed
        under Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0),
        with the licensors' additional permission for individual creators (2026-09-16):
          • A person — a musician, a content creator, anyone acting as an individual — may
            use the weights free of charge and publish, sell, license or otherwise monetise
            the songs they make, including for clients and on commercial platforms.
          • Companies may NOT use the weights commercially without a separate licence
            from the licensors (ryuanab@connect.ust.hk). Students, educators and
            researchers: free for non-commercial research and education.
          • Never for illegal, harmful, deceptive or unethical purposes (fraud, harassment,
            deceptive impersonation); you are responsible for your inputs, the outputs and
            the rights and consents they need.
          • The weights themselves may not be sold or redistributed commercially; sharing
            them needs CC BY-NC attribution. Crediting YuE2 on songs is encouraged, optional.
          • No warranty. The tokenizer file and third-party code keep their own terms.
        Full terms: \(modelLicenceURL.absoluteString)
        CC BY-NC 4.0: \(url.absoluteString) (also LICENSE beside the model).
        """

    /// The licensors' additional permission, verbatim from MODEL_LICENSE at ``modelLicenceURL``.
    public static let individualCreatorPermission = """
    Individual creator permission and academic use (2026-09-16)
    ---------------------------------------------------------

    Individual creators and output monetization
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    In addition to the CC BY-NC 4.0 license below, the YuE2 model licensors
    grant personal users, content creators and musicians acting in an
    individual capacity permission to use the model weights free of charge
    to generate outputs, and to publish, distribute, sell, license or
    otherwise monetize those outputs, subject to the responsible-use
    conditions below.

    For these individual creative activities, the model licensors waive the
    NonCommercial restriction to the extent necessary. These users do not
    need a separate commercial license from, or owe license fees or
    royalties to, the model licensors for this use or for monetizing their
    outputs. This includes distributing or licensing their outputs to
    clients and publishing them on commercial platforms.

    Academic use
    ~~~~~~~~~~~~

    Students, educators, researchers and academic institutions may use YuE2
    free of charge for non-commercial research and education under the
    CC BY-NC 4.0 license below. This academic-use provision does not itself
    grant commercial-use rights to an institution. An academic user
    creating work in an individual capacity may rely on the individual
    creator permission above.

    Credit and other terms
    ~~~~~~~~~~~~~~~~~~~~~~

    We strongly encourage users to credit YuE2 by including the model name
    or the #YuE2 tag when sharing generated work. Credit on generated
    outputs is optional and is not a condition of this additional permission
    or of output monetization. This recommendation does not waive the
    attribution requirements for sharing model weights or adapted weights.

    The individual creator permission does not authorize commercial use
    of the model weights by companies. Companies wishing to use the model weights commercially
    should contact ryuanab@connect.ust.hk to discuss a commercial license:
    https://github.com/multimodal-art-projection/YuE#contact

    Responsible use is a condition of this additional permission. Under
    this permission, you must not use the model weights or generated
    outputs for illegal, harmful, deceptive or otherwise unethical purposes,
    including fraud, harassment or deceptive impersonation. You are
    responsible for your inputs, outputs and use of the model, including
    obtaining any necessary rights and consent.

    To the extent permitted by applicable law, the model weights and the
    additional permission are provided as is, without warranties of any
    kind. The model licensors and authors disclaim liability for misuse
    and any resulting claims, losses or damages. Nothing in this statement
    excludes liability that cannot lawfully be excluded.

    This permission concerns generating and using outputs; it does not
    extend to commercial redistribution or sale of the model weights.
    All other applicable CC BY-NC 4.0 conditions continue to apply to the
    weights. Generated outputs are not subject to the model weights'
    NonCommercial restriction solely because they were generated with YuE2.

    This additional permission and its responsible-use conditions are
    separate from the unmodified CC BY-NC 4.0 license below. They do not
    restrict rights already granted under CC BY-NC 4.0, Apache 2.0 or
    earlier grants of additional permission. This permission covers
    only rights the model licensors have authority to grant and does not
    grant rights in third-party material used in inputs or outputs.
    """

    /// The credit the licensors encourage on a shared song (optional under the individual-creator permission).
    public static let attribution =
        "Made with YuE2 (m-a-p/YuE2-3B) #YuE2 — weights CC BY-NC 4.0 with the individual-creator permission."
}
