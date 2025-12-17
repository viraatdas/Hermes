import styles from "./page.module.css";

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
            className={styles.primary}
            href="https://github.com/viraatdas/Hermes/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
          >
            Download Hermes
          </a>
          <div className={styles.meta}>
            <a
              className={styles.link}
              href="https://github.com/viraatdas/Hermes"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
            <span className={styles.dot} aria-hidden="true">
              ·
            </span>
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
