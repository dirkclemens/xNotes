//
//  LinkCleaner.swift
//  xNotes
//

import Foundation

/// Removes tracking parameters from copied web links (utm_source, fbclid, …).
/// Only parameters known to be tracking are removed; those a page needs to show the
/// right content (a video id, a search term, a page number) stay.
enum LinkCleaner {
    struct Result: Equatable {
        let url: URL
        /// Names of the removed parameters, e.g. ["utm_source", "fbclid"].
        let removed: [String]
    }

    /// The link without tracking parameters, or nil if there was nothing to remove.
    static func clean(_ url: URL) -> Result? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }

        var removed: [String] = []
        if let items = components.percentEncodedQueryItems, !items.isEmpty {
            let kept = items.filter { item in
                guard isTracking(item.name, host: host) else { return true }
                if !removed.contains(item.name) { removed.append(item.name) }
                return false
            }
            if kept.count != items.count {
                components.percentEncodedQueryItems = kept.isEmpty ? nil : kept
            }
        }

        // Amazon puts tracking into the path: /dp/B0123/ref=sr_1_1
        if isHost(host, in: ["amazon"]), let range = components.percentEncodedPath.range(of: "/ref=") {
            components.percentEncodedPath = String(components.percentEncodedPath[..<range.lowerBound])
            removed.append("ref")
        }

        guard !removed.isEmpty, let cleaned = components.url else { return nil }
        return Result(url: cleaned, removed: removed)
    }

    /// Cleans the text if it is a single web link; otherwise returns nil.
    static func clean(text: String) -> Result? {
        guard let url = ClipboardFormats.webURL(in: text) else { return nil }
        return clean(url)
    }

    // MARK: - Rules

    /// Tracking parameters used across many sites (analytics, ad and newsletter tools).
    private static let commonParameters: Set<String> = [
        // Google Analytics / Ads
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "_ga", "_gl", "_gac",
        // Facebook, Instagram, Microsoft, Yandex, TikTok, Twitter ads
        "fbclid", "igshid", "igsh", "msclkid", "yclid", "ttclid", "twclid", "li_fat_id",
        // Mailchimp, HubSpot, Marketo, Vero, Oracle Eloqua, Klaviyo
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "__hstc", "__hssc", "__hsfp", "hsctatracking",
        "mkt_tok", "vero_id", "vero_conv", "elqtrackid", "elqtrack", "_kx",
        // Others
        "oly_anon_id", "oly_enc_id", "rb_clickid", "s_cid", "wickedid", "trk_contact",
        "trk_msg", "trk_module", "trk_sid", "ncid", "sr_share", "spm", "scm",
        "ref_src", "ref_url",
    ]

    /// Prefixes of parameter families, e.g. utm_source, utm_medium, utm_campaign.
    private static let commonPrefixes = ["utm_", "pk_", "mtm_", "piwik_", "matomo_", "hmb_"]

    /// Parameters that are tracking only on certain sites; elsewhere they may mean something.
    private static let siteParameters: [(hosts: [String], parameters: Set<String>)] = [
        (["youtube", "youtu"], ["si", "pp", "feature"]),
        (["spotify"], ["si", "nd", "context"]),
        (["twitter", "x"], ["s", "t"]),
        (["linkedin"], ["trackingid", "trk", "lipi", "lici", "refid", "midtoken", "midsig", "eid", "otptoken"]),
        (["instagram"], ["utm_source", "igsh", "img_index"]),
        (["tiktok"], ["_r", "_t", "is_from_webapp", "sender_device", "is_copy_url", "share_app_id", "share_link_id"]),
        (["amazon"], ["ref", "ref_", "pd_rd_r", "pd_rd_w", "pd_rd_wg", "pd_rd_i", "pf_rd_p", "pf_rd_r",
                      "pf_rd_s", "pf_rd_t", "pf_rd_i", "pf_rd_m", "content-id", "crid", "sprefix", "qid",
                      "sr", "dib", "dib_tag", "_encoding", "linkcode", "tag", "linkid", "camp", "creative"]),
        (["ebay"], ["_trkparms", "_trksid", "hash", "amdata", "mkevt", "mkcid", "mkrid", "campid", "toolid", "customid"]),
        (["aliexpress"], ["spm", "scm", "pvid", "algo_pvid", "algo_exp_id", "aff_platform", "sk", "aff_trace_key"]),
        (["reddit"], ["share_id", "rdt", "ref_source", "ref_campaign"]),
        (["medium"], ["source", "sk"]),
        (["google"], ["ved", "ei", "sa", "usg", "sca_esv", "sxsrf", "gs_lcrp", "gs_lp", "sclient", "oq", "aqs",
                      "sourceid", "uact", "biw", "bih", "dpr", "client", "rlz"]),
        (["bing"], ["form", "sp", "pq", "sc", "qs", "sk", "cvid", "ghsh", "ghacc", "ghpl"]),
    ]

    /// `ref` is a common referral tag, but code hosts use it for branches and commits.
    private static let refHostsToKeep = ["github", "gitlab", "bitbucket", "codeberg"]

    private static func isTracking(_ name: String, host: String) -> Bool {
        let name = name.lowercased()
        if commonParameters.contains(name) || commonPrefixes.contains(where: name.hasPrefix) {
            return true
        }
        if name == "ref" {
            return !isHost(host, in: refHostsToKeep)
        }
        return siteParameters.contains { rule in
            rule.parameters.contains(name) && isHost(host, in: rule.hosts)
        }
    }

    /// Whether the host belongs to one of the sites, by the name before the domain ending:
    /// "amazon" matches amazon.de, www.amazon.co.uk and smile.amazon.com.
    private static func isHost(_ host: String, in sites: [String]) -> Bool {
        let labels = host.split(separator: ".").map(String.init)
        return sites.contains { site in
            guard let index = labels.lastIndex(of: site) else { return false }
            // Only the ending may follow (com, de, co.uk), so "x.example.com" isn't x.com.
            let ending = labels[(index + 1)...]
            return !ending.isEmpty && ending.count <= 2 && ending.allSatisfy { $0.count <= 3 }
        }
    }
}
