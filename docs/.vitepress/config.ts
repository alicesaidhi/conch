import { defineConfig } from "vitepress";
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'

// https://vitepress.dev/reference/site-config
export default defineConfig({

    title: "Conch",
    titleTemplate: ":title - Console",
    description: "Modular and powerful console for Roblox developers",
    base: "/conch/",
    head: [
        ["link", { rel: "icon", href: "/conch/logo.svg" }],
        ["link", { rel: "preconnect", href: "https://fonts.googleapis.com" }],
        ["link", { rel: "preconnect", href: "https://fonts.gstatic.com", crossorgin: '' }],
        ["link", { rel: "stylesheet", href: "https://fonts.googleapis.com/css2?family=JetBrains+Mono:ital,wght@0,100..800;1,100..800&display=swap" }]
    ],
    cleanUrls: true,

    vite: {
        ssr: {
            noExternal: [
                '@nolebase/vitepress-plugin-highlight-targeted-heading',
            ]
        }
    },
    
    markdown: {
        config(md) {
            md.use(tabsMarkdownPlugin);
        }
    },

    themeConfig: {
        logo: "/logo.svg",

        search: {
            provider: "local"
        },

        footer: {
            message: 'Released under the MIT License.',
        },

        // https://vitepress.dev/reference/default-theme-config
        nav: [
            { text: "Home", link: "/" },
            { text: "Resources", link: "/resources/getting-started/1-why" },
            { text: "API", link: "/api/conch"},
			{ text: "Glossary", link: "/resources/glossary" },
        ],

        sidebar: {
            "/api/": [
                { text: "conch", link: "/api/conch" },
				{ text: "ui", link: "/api/ui" },
            ],
            "/resources/": [
				{ text: "Glossary", link: "/resources/glossary" },
                { text: "Getting Started", collapsed: false, items: [
                    { text: "Why", link: "/resources/getting-started/1-why" },
                    { text: "Installation", link: "/resources/getting-started/2-installation" },
                    { text: "Setting Up", link: "/resources/getting-started/3-setting-up" },
					{ text: "Permissions", link: "/resources/getting-started/4-permissions" },
					{ text: "Custom Commands", link: "/resources/getting-started/5-custom-commands" },
					{ text: "Troubleshooting", link: "/resources/getting-started/6-troubleshooting" },
                ] },
                { text: "Concepts", collapsed: false, items: [
					{ text: "Types", link: "/resources/advanced-concepts/types" },
					{ text: "Syntax", link: "/resources/advanced-concepts/syntax" },
                ] },
				
            ]
        },

        socialLinks: [
            { icon: "github", link: "https://github.com/alicesaidhi/conch" }
        ]
    }

})