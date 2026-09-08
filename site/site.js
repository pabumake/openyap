const feedURL = "./appcast.xml";
const repositoryURL = "https://github.com/pabumake/openyap";
const releasesURL = `${repositoryURL}/releases`;
const allowedDownloadPrefix = "/pabumake/openyap/releases/download/";
const sparkleNamespace = "http://www.andymatuschak.org/xml-namespaces/sparkle";

const downloadLink = document.querySelector("#download-link");
const releaseLink = document.querySelector("#release-link");
const releaseStatus = document.querySelector("#release-status");

function trustedGitHubURL(rawURL, requiredPathPrefix) {
  const url = new URL(rawURL);
  if (url.protocol !== "https:" || url.hostname !== "github.com") {
    throw new Error("The release URL uses an unexpected host.");
  }
  if (!url.pathname.startsWith(requiredPathPrefix)) {
    throw new Error("The release URL uses an unexpected path.");
  }
  return url.toString();
}

function formatBytes(rawBytes) {
  const bytes = Number(rawBytes);
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return null;
  }
  return `${(bytes / 1_048_576).toFixed(1)} MB`;
}

async function loadCurrentRelease() {
  try {
    const response = await fetch(feedURL, { cache: "no-cache" });
    if (!response.ok) {
      throw new Error(`The update feed returned HTTP ${response.status}.`);
    }

    const xml = new DOMParser().parseFromString(await response.text(), "application/xml");
    if (xml.querySelector("parsererror")) {
      throw new Error("The update feed contains invalid XML.");
    }

    const item = xml.querySelector("channel > item");
    const enclosure = item?.querySelector("enclosure");
    const versionNode = item?.getElementsByTagNameNS(sparkleNamespace, "shortVersionString")[0];
    const version = versionNode?.textContent?.trim();
    const rawDownloadURL = enclosure?.getAttribute("url");

    if (!version || !/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(version) || !rawDownloadURL) {
      throw new Error("The update feed has no valid current release.");
    }

    downloadLink.href = trustedGitHubURL(rawDownloadURL, allowedDownloadPrefix);
    downloadLink.textContent = `Download v${version}`;

    const rawReleaseURL = item?.querySelector("link")?.textContent?.trim();
    if (rawReleaseURL) {
      releaseLink.href = trustedGitHubURL(rawReleaseURL, "/pabumake/openyap/releases/tag/");
    }

    const size = formatBytes(enclosure.getAttribute("length"));
    releaseStatus.textContent = [`Version ${version}`, size, "ZIP archive"].filter(Boolean).join(" · ");
  } catch (error) {
    downloadLink.href = releasesURL;
    downloadLink.textContent = "View releases";
    releaseLink.href = releasesURL;
    releaseStatus.textContent = "Open the releases page for the current download.";
    console.warn("OpenYap release details are unavailable.", error);
  }
}

loadCurrentRelease();
