# MageStart

## Magefine's Magento Setup Script 🚀

Hey there, Magento devs! This script is here to make your life a little easier. Whether you’re setting up a brand-new Magento project or trying to wrestle with an existing one, we’ve got you covered.

---

### What Does It Do? 🌟

1. **Handles Your `.env` for You**
    - Don’t have a `.env` file? It’ll create one.
    - Missing variables? It’ll ask for them (with smart defaults).

2. **Works with Existing Projects**
    - Automatically grabs files like `magefine-compose.yml`.
    - Builds and starts your Docker containers.

3. **Sets Up Fresh Projects**
    - Fixes those pesky permissions automatically.

4. **Deals with Databases**
    - Option to initialize a new database or restore from a dump.

5. **Keeps Things on Track**
    - Checks for Docker and cURL so nothing breaks halfway through.

---

### How to Use It? 🤔

No need to clone anything! Run this one-liner in your terminal and let the magic happen:
```bash  
bash < (curl -s https://raw.githubusercontent.com/Magefine/MageStart/refs/heads/master/install.sh)
