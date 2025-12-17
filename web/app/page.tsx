import styles from "./page.module.css";
import Image from "next/image";

function AppleMark(props: { className?: string }) {
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
        d="M16.7 12.5c0-2 1.6-3 1.7-3.1-1-.9-2.5-1-3-1-1.3-.1-2.5.8-3.2.8-.6 0-1.6-.8-2.7-.8-1.4 0-2.7.8-3.4 2-1.5 2.6-.4 6.4 1 8.5.7 1 1.6 2.1 2.8 2.1 1.1 0 1.6-.7 2.9-.7 1.3 0 1.7.7 3 .7 1.2 0 2-.9 2.7-2 .8-1.2 1.1-2.4 1.2-2.5-.1 0-2.3-.9-2.3-3.9Z"
      />
      <path
        fill="currentColor"
        d="M14.9 3.2c.6-.8 1-1.9.9-3-.9.1-2 .6-2.6 1.4-.6.7-1.1 1.9-.9 3 .9.1 2-.5 2.6-1.4Z"
      />
    </svg>
  );
}

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
          <div className={styles.heroRow}>
            <Image className={styles.logoImg} src="/icon.png" alt="Hermes" width={44} height={44} priority />
            <div className={styles.titleBlock}>
              <div className={styles.titleRow}>
                <h1 className={styles.title}>Hermes</h1>
                <span className={styles.badge}>Beta</span>
              </div>
              <div className={styles.platformRow}>
                <AppleMark className={styles.appleIcon} />
                <span className={styles.platformText}>macOS</span>
              </div>
            </div>
          </div>
          <p className={styles.subtitle}>
            A discrete meeting recorder for macOS. Local-first. One click to record and
            transcribe.
          </p>
        </header>

        <section className={styles.actions}>
          <a
            className={styles.badgeLink}
            href="https://github.com/viraatdas/Hermes/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Image
              className={styles.downloadBadge}
              src="/download-badge.svg"
              alt="Download Hermes"
              width={240}
              height={80}
              priority
            />
          </a>
          <div className={styles.meta}>
            <a
              className={styles.link}
              href="https://github.com/viraatdas/Hermes"
              target="_blank"
              rel="noopener noreferrer"
            >
              <GitHubMark className={styles.githubIcon} />
              GitHub
            </a>
            <span className={styles.dot} aria-hidden="true">
              ·
            </span>
            <span className={styles.muted}>Suggestions / contact:</span>
            <a className={styles.link} href="mailto:viraat@exla.ai">
              viraat@exla.ai
            </a>
          </div>
        </section>

        <footer className={styles.footer}>
          <p className={styles.finePrint}>
            By downloading, you understand Hermes is in beta and may change quickly.
          </p>
        </footer>
      </main>
    </div>
  );
}
