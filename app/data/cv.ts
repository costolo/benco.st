export interface CvLink {
  label: string
  href?: string
  icon?: string
  external?: boolean
}

export interface CvProfile {
  name: string
  title: string
  contact: CvLink[]
}

export interface CvSkillGroup {
  title: string
  items: string[]
}

export interface CvEducationEntry {
  degree: string
  institution: string
  start: string
  end: string
}

export interface CvExperienceEntry {
  role: string
  company: string
  companyUrl?: string
  location: string
  start: string
  end: string
  summary?: string
  highlights: string[]
}

export interface CvData {
  profile: CvProfile
  skills: CvSkillGroup[]
  education: CvEducationEntry[]
  experience: CvExperienceEntry[]
}

export const cv: CvData = {
  profile: {
    name: 'Ben Costolo',
    title: 'Software Engineer',
    contact: [
      { label: 'me@benco.st', href: 'mailto:me@benco.st', icon: 'i-uil:at' },
      {
        label: 'https://benco.st',
        href: 'https://benco.st',
        icon: 'i-uil:link',
        external: true,
      },
      {
        label: 'https://linkedin.com/in/costolo',
        href: 'https://linkedin.com/in/costolo',
        icon: 'i-logos:linkedin-icon',
        external: true,
      },
      { label: 'New York, NY', icon: 'i-uil:location' },
    ],
  },

  skills: [
    {
      title: 'Languages',
      items: ['JavaScript', 'Typescript', 'HTML', 'CSS', 'SCSS', 'Python', 'Ruby', 'PHP', 'SQL', 'C#'],
    },
    {
      title: 'Frameworks',
      items: ['React', 'Vue', 'Node', 'Express', 'Flask', 'Rails', 'Laravel', 'NextJS', 'Storybook'],
    },
    {
      title: 'Tools',
      items: [
        'Git',
        'Unix',
        'Docker',
        'PostgreSQL',
        'Google Cloud Platform',
        'Claude Code',
        'Sentry',
        'New Relic',
        'Datadog',
        'CircleCI',
        'GitHub Actions',
        'Jest',
        'Chromatic',
        'Enzyme',
        'React Testing Library',
      ],
    },
  ],

  education: [
    {
      degree: 'Degree and Field of Study',
      institution: 'Dev Bootcamp - NYC cohort',
      start: '11/2014',
      end: '03/2015',
    },
    {
      degree: 'B.S. Microbiology',
      institution: 'North Carolina State University',
      start: '08/2010',
      end: '12/2014',
    },
  ],

  experience: [
    {
      role: 'Software Engineer',
      company: 'Neptune Flood',
      location: 'Remote',
      start: '05/2025',
      end: '09/2026',
      summary: 'Neptune Flood is America\'s largest private flood insurance provider.',
      highlights: [
        'Increased user engagement on our direct-to-consumer application by 80% by overhauling the UI experience, with LaunchDarkly integration for A/B testing across the funnel.',
        'Translated customer feedback into redesigned profile pages for individual user management as well as agency management.',
        'Delivered the frontend of an authentication revamp migrating customers from shared one-to-many accounts to individual one-to-one accounts, including new registration, sign-in, and account management flows, all backed by unit and integration tests.',
        'Built state-gated compliance disclosure flows for California and Maine that intercept quote and bind, keeping a single funnel codebase compliant across differing legal jurisdictions.',
        'Shipped the UI for Indemnity Earthquake, a full-coverage earthquake product, from quote and disclosure through bind and policy servicing.'
      ]
    },
    {
      role: 'Software Engineer',
      company: 'Aperture Education',
      location: 'Remote',
      start: '04/2022',
      end: '02/2024',
      summary:
        'Aperture Education provides industry-leading and science-backed student assessments to empower growth.',
      highlights: [
        'Participated in design sessions, coordinated with product and back-end engineering teams, and routinely provided large groups of stakeholders biweekly project updates via Confluence.',
        'Led the development across the stack of our data-driven Student Intervention Package product offering.',
        'Led planning and implementation of an overhaul to our front-end unit and end-to-end testing, increasing test-coverage by over 40%.',
        'Implemented automated deployments, hosting, and interaction testing of Storybook stories, helping to optimize the time of our QA engineers.',
        'Increased insight into web application health by implementing front-end monitoring via New Relic, providing our team with reliable hard data on site reliability.',
        'Helped to plan and implement a new feature development procedure including Git branching strategy and release automation, standardizing disparate styles into one.',
      ],
    },
    {
      role: 'Software Engineer II',
      company: 'Trade Coffee Co',
      location: 'Remote',
      start: '03/2020',
      end: '03/2022',
      summary:
        'Trade Coffee are leaders in the delivery of freshly roasted specialty coffee directly to doorstep.',
      highlights: [
        'Built test backed APIs in Express and Rails, and their respective clients on the front end at a 100% coverage rate.',
        'Led the implementation of Redux for front end state management, increasing test coverage on core front-end business logic by 40%.',
        'Wrote a custom library to consume our headless CMS in order to provide non-technical team members dynamic control over copy and layout styling of React components in staging and production without the need for code changes.',
        'Worked closely with our design and platform team to implement unique experiences for high traffic gifting seasons, reaching over 1M unique visitors.',
        'Built a prototype mobile application in React Native.',
      ],
    },
    {
      role: 'Software Engineer',
      company: 'Torch Dental',
      location: 'New York City, NY',
      start: '02/2019',
      end: '02/2020',
      summary: 'Torch Dental is the All-In-One Dental Supply Platform built to save practices money',
      highlights: [
        'Led the team to adopt a standard for front-end code formatting and implemented automated code formatting prior to commits being merged into the repo, leading to a higher burn rate during our sprints by roughly 10%.',
        'Improved test coverage of front-end business logic by 90% through leading the refactoring of front-end logic to Redux sagas.',
        'Actively participated in cross-functional design sessions, taking features from ideation to production.',
        'Added site-wide responsiveness while refactoring a monolithic sass file to 30+ modular component stylesheets.',
      ],
    },
    {
      role: 'Full Stack Software Engineer',
      company: 'Phido/Petflow',
      location: 'New York City, NY',
      start: '04/2017',
      end: '01/2019',
      summary: 'Company Description',
      highlights: [
        'Launched the React client and Laravel API of our ~$3M/year e-commerce platform Endless Aisles.',
        'Built an internal Laravel application with 100% test coverage for managing Endless Aisles customers and orders.',
        'Built a React/Redux web application to help standardize geographic data and unique identification of 1000+ pet stores for analytics insight.',
        'Developed new features and provided legacy support for Petflow.com, a $50M/year specialty pet e-commerce site.',
      ],
    },
  ],
}
