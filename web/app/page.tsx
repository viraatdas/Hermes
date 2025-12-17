import styles from "./page.module.css";
import Image from "next/image";

function GitHubMark(props: { className?: string }) {
  return (
    <svg
      className={props.className}
      viewBox="0 0 24 24"
      width="16"
      height="16"
      aria-hidden="true"
      focusable="false"
    >
      <path
        fill="currentColor"
        d="M12 2c5.5 0 10 4.6 10 10.2 0 4.5-2.9 8.3-6.9 9.6-.5.1-.7-.2-.7-.5v-1.8c0-.6-.2-1-.4-1.3 1.4-.2 2.9-.7 2.9-3.4 0-.8-.3-1.5-.7-2 .1-.2.3-1-.1-2.1 0 0-.6-.2-2.1.8-.6-.2-1.3-.3-2-.3s-1.4.1-2 .3c-1.5-1-2.1-.8-2.1-.8-.4 1.1-.2 1.9-.1 2.1-.5.5-.7 1.2-.7 2 0 2.7 1.5 3.2 2.9 3.4-.2.2-.4.5-.4 1v2.1c0 .3-.2.6-.7.5C4.9 20.5 2 16.7 2 12.2 2 6.6 6.5 2 12 2Z"
      />
    </svg>
  );
}

export default function Home() {
  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <header className={styles.header}>
          <div className={styles.titleRow}>
            <h1 className={styles.title}>Hermes</h1>
            <span className={styles.badge}>Beta</span>
          </div>
          <p className={styles.subtitle}>
            A discrete meeting recorder for macOS. Local-first. One click to record and
            transcribe.
          </p>
        </header>

        <section className={styles.actions}>
          <a
            className={styles.badgeLink}
            href="https://github.com/viraatdas/Hermes/releases/download/v0.1.7/Hermes-v0.1.7.dmg"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Image
              className={styles.downloadBadge}
              src="/download-badge.svg"
              alt="Download Hermes"
              width={210}
              height={70}
              priority
            />
          </a>
          <div className={styles.meta}>
            <div className={styles.metaRow}>
              <span className={styles.muted}>Open source</span>
              <span className={styles.dot} aria-hidden="true">
                ·
              </span>
              <a
                className={styles.link}
                href="https://github.com/viraatdas/Hermes"
                target="_blank"
                rel="noopener noreferrer"
              >
                <GitHubMark className={styles.githubIcon} />
                GitHub
              </a>
            </div>
            <div className={styles.metaRow}>
              <span className={styles.muted}>Suggestions / contact:</span>
              <a className={styles.link} href="mailto:viraat@exla.ai">
                viraat@exla.ai
              </a>
            </div>
          </div>
        </section>

      </main>
    </div>
  );
}
